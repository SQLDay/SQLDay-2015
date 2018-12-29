using System;
using System.Collections.Generic;
using AdamMachanic.QueryTools;
using System.Data;
using System.Data.SqlTypes;
using System.Data.SqlClient;
using Microsoft.SqlServer.Server;

public partial class StoredProcedures
{
    [Microsoft.SqlServer.Server.SqlProcedure]
    public static void GetHotelStayIntervalCounts_Parallelizer(
        SqlInt32 MinHotelId, 
        SqlInt32 MaxHotelId, 
        SqlInt32 NumThreads)
    {
        var qp =
            new QueryParallelizer<ResultWithHotelId>(
                @"SELECT
                    HotelId,
                    CheckInDate,
                    CheckOutDate
                FROM dbo.HotelStays
                WHERE
                    HotelId BETWEEN @minHotelId AND @maxHotelId
                ORDER BY
                    HotelId,
                    CheckInDate",
                "@minHotelId", "@maxHotelId",
                MinHotelId.Value, MaxHotelId.Value,
                NumThreads.Value,
                processResults);

        SqlDataRecord dr = new SqlDataRecord(
            new SqlMetaData("HotelId", SqlDbType.Int),
            new SqlMetaData("intervalStart", SqlDbType.Date),
            new SqlMetaData("intervalEnd", SqlDbType.Date),
            new SqlMetaData("numberOfRooms", SqlDbType.Int));

        SqlContext.Pipe.SendResultsStart(dr);

        foreach (ResultWithHotelId rh in qp.Process())
        {
            dr.SetInt32(0, rh.HotelId);
            dr.SetDateTime(1, rh.Result.Start);
            dr.SetDateTime(2, rh.Result.End);
            dr.SetInt32(3, rh.Result.Count);

            SqlContext.Pipe.SendResultsRow(dr);
        }

        SqlContext.Pipe.SendResultsEnd();
    }

    public static IEnumerable<ResultWithHotelId> processResults(SqlDataReader reader)
    {
        var i = new intervals.IntervalCounter();

        int currentHotel = int.MinValue;

        while (reader.Read())
        {
            if (currentHotel != reader.GetInt32(0))
            {
                if (currentHotel != int.MinValue)
                {
                    //send the results
                    foreach (intervals.IntervalCounter.Result r in i.Terminate())
                        yield return (new ResultWithHotelId() { Result = r, HotelId = currentHotel });
                }

                currentHotel = reader.GetInt32(0);
                i.Init();
            }

            i.Accumulate(reader.GetDateTime(1), reader.GetDateTime(2));
        }

        //send back the final set of results
        foreach (intervals.IntervalCounter.Result r in i.Terminate())
            yield return (new ResultWithHotelId() { Result = r, HotelId = currentHotel });
    }

    public class ResultWithHotelId
    {
        public intervals.IntervalCounter.Result Result;
        public int HotelId;
    }
}
