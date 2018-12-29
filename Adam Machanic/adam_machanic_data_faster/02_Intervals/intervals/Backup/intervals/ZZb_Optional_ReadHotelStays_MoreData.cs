using System;
using System.Data;
using System.Data.SqlClient;
using System.Data.SqlTypes;
using Microsoft.SqlServer.Server;
using System.Collections.Generic;

public partial class StoredProcedures
{
    [Microsoft.SqlServer.Server.SqlProcedure]
    public static void ReadHotelStays_MoreData(
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
                    h.HotelId,
                    hs.CheckInDate,
                    hs.CheckOutDate,
                    hs.StayId,
                    h.HotelName,
                    h.AddressLine1,
                    h.AddressLine2,
                    h.City,
                    h.StateProvince,
                    h.PostalCode,
                    h.CountryRegion,
                    h.NumberOfRooms
                FROM dbo.HotelStays AS hs
                INNER JOIN dbo.Hotels AS h ON
                    h.HotelId = hs.HotelId
                WHERE
                    h.HotelId BETWEEN @minHotelId AND @maxHotelId
                ORDER BY
                    h.HotelId,
                    hs.CheckInDate";

            comm.Parameters.AddWithValue("@minHotelId", MinHotelId);
            comm.Parameters.AddWithValue("@maxHotelId", MaxHotelId);

            conn.Open();

            var reader = comm.ExecuteReader(CommandBehavior.CloseConnection);

            int rowCount = 0;

            while (reader.Read())
            {
                rowCount++;
            }

            SqlContext.Pipe.Send(String.Format("Read {0} rows", rowCount));
        }
    }
};
