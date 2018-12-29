using System;
using System.Data;
using System.Data.SqlClient;
using System.Data.SqlTypes;
using Microsoft.SqlServer.Server;
using System.Collections.Generic;

public partial class StoredProcedures
{
    [Microsoft.SqlServer.Server.SqlProcedure]
    public static void GetHotelStayIntervalCounts(
        SqlInt32 MinHotelId,
        SqlInt32 MaxHotelId)
    {
        SqlConnectionStringBuilder sb = new SqlConnectionStringBuilder();
        sb.ContextConnection = true;

        using (var conn = new SqlConnection(sb.ConnectionString))
        {
            var comm = conn.CreateCommand();
            comm.CommandText =
                @"SELECT
                    HotelId,
                    CheckInDate,
                    CheckOutDate
                FROM dbo.HotelStays
                WHERE
                    HotelId BETWEEN @minHotelId AND @maxHotelId
                ORDER BY
                    HotelId,
                    CheckInDate";

            comm.Parameters.AddWithValue("@minHotelId", MinHotelId);
            comm.Parameters.AddWithValue("@maxHotelId", MaxHotelId);

            conn.Open();

            var reader = comm.ExecuteReader(CommandBehavior.CloseConnection);

            var i = new intervals.IntervalCounter();

            SqlDataRecord dr = new SqlDataRecord(
                new SqlMetaData("HotelId", SqlDbType.Int),
                new SqlMetaData("intervalStart", SqlDbType.Date),
                new SqlMetaData("intervalEnd", SqlDbType.Date),
                new SqlMetaData("numberOfRooms", SqlDbType.Int));

            SqlContext.Pipe.SendResultsStart(dr);

            int currentHotel = int.MinValue;

            while (reader.Read())
            {
                if (currentHotel != reader.GetInt32(0))
                {
                    if (currentHotel != int.MinValue)
                    {
                        dr.SetInt32(0, currentHotel);

                        //send the results
                        foreach (intervals.IntervalCounter.Result r in i.Terminate())
                        {
                            dr.SetDateTime(1, r.Start);
                            dr.SetDateTime(2, r.End);
                            dr.SetInt32(3, r.Count);

                            SqlContext.Pipe.SendResultsRow(dr);
                        }
                    }

                    currentHotel = reader.GetInt32(0);
                    i.Init();
                }

                i.Accumulate(reader.GetDateTime(1), reader.GetDateTime(2));
            }

            //send back the final set of results
            foreach (intervals.IntervalCounter.Result r in i.Terminate())
            {
                dr.SetDateTime(1, r.Start);
                dr.SetDateTime(2, r.End);
                dr.SetInt32(3, r.Count);

                SqlContext.Pipe.SendResultsRow(dr);
            }

            SqlContext.Pipe.SendResultsEnd();
        }
    }
};
