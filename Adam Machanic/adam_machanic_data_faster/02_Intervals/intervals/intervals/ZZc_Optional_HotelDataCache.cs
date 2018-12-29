using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

public class HotelDataCache
{
    //Put this into a trigger on the hotels table, to clear the cache
    [Microsoft.SqlServer.Server.SqlProcedure]
    public static void ClearHotelDataCache()
    {
        hotels.Clear();
    }

    //each array will hold up to 100 hotels
    private static readonly AdamMachanic.QueryTools.BoundlessArray<Hotel[]> hotels = 
        new AdamMachanic.QueryTools.BoundlessArray<Hotel[]>();

    public static Hotel GetHotel(int HotelId)
    {
        //try to grab a block of 100 hotels
        Hotel[] hotelBlock = hotels[HotelId / 100];

        //not null means we've hit the block before...
        if (hotelBlock != null)
            return (hotelBlock[HotelId % 100]);
        else
        {
            //no hotel block? Try making a new one
            hotelBlock = new Hotel[100];

            var gd = 
                new AdamMachanic.QueryTools.GetDataAsync(
                @"SELECT
                    h.HotelId,
                    h.HotelName,
                    h.AddressLine1,
                    h.AddressLine2,
                    h.City,
                    h.StateProvince,
                    h.PostalCode,
                    h.CountryRegion,
                    h.NumberOfRooms
                FROM dbo.Hotels AS h 
                WHERE
	                h.HotelId BETWEEN @MinHotelId AND @MaxHotelId");

            //Define the block of hotels to grab
            System.Data.SqlClient.SqlParameter[] p = new System.Data.SqlClient.SqlParameter[2];
            p[0] = new System.Data.SqlClient.SqlParameter("@MinHotelId", (HotelId / 100) * 100);
            p[1] = new System.Data.SqlClient.SqlParameter("@MaxHotelId", ((HotelId / 100) * 100) + 99);

            gd.Parameters = p;

            foreach (object[] o in gd.GetData())
            {
                int hotelId = (int)o[0];
                string hotelName = (string)o[1];
                string addressLine1 = (string)o[2];
                string addressLine2 = (o[3] is DBNull) ? null : (string)o[3];
                string city = (string)o[4];
                string stateProvince = (string)o[5];
                string postalCode = (string)o[6];
                string countryRegion = (string)o[7];
                Int16 numberOfRooms = (Int16)o[8];

                hotelBlock[hotelId % 100] =
                    new Hotel(
                        hotelId,
                        hotelName,
                        addressLine1,
                        addressLine2,
                        city,
                        stateProvince,
                        postalCode,
                        countryRegion,
                        numberOfRooms);
            }

            //populate the block into the hotels collection
            hotels[HotelId / 100] = hotelBlock;

            return (hotelBlock[HotelId % 100]);
        }
    }

    public class Hotel
    {
        public Hotel(
            int HotelId,
            string HotelName,
            string AddressLine1,
            string AddressLine2,
            string City,
            string StateProvince,
            string PostalCode,
            string CountryRegion,
            Int16 NumberOfRooms)
        {
            this.HotelId = HotelId;
            this.HotelName = HotelName;
            this.AddressLine1 = AddressLine1;
            this.AddressLine2 = AddressLine2;
            this.City = City;
            this.StateProvince = StateProvince;
            this.PostalCode = PostalCode;
            this.CountryRegion = CountryRegion;
            this.NumberOfRooms = NumberOfRooms;
        }

        public readonly int HotelId;
        public readonly string HotelName;
        public readonly string AddressLine1;
        public readonly string AddressLine2;
        public readonly string City;
        public readonly string StateProvince;
        public readonly string PostalCode;
        public readonly string CountryRegion;
        public readonly Int16 NumberOfRooms;
    }
}
