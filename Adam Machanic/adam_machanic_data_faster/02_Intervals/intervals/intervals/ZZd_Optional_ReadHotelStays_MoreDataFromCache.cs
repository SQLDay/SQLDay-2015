using System;
using System.Data;
using System.Data.SqlClient;
using System.Data.SqlTypes;
using Microsoft.SqlServer.Server;
using System.Collections.Generic;

public partial class StoredProcedures
{
    [Microsoft.SqlServer.Server.SqlProcedure]
    public static void ReadHotelStays_MoreDataFromCache(
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

            int rowCount = 0;

            while (reader.Read())
            {
                //exercise the cache
                if (HotelDataCache.GetHotel(reader.GetInt32(0)) != null)
                    rowCount++;
            }

            SqlContext.Pipe.Send(String.Format("Read {0} rows", rowCount));
        }
    }
};
