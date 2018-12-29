using System;
using System.Data;
using System.Data.SqlClient;
using System.Data.SqlTypes;
using Microsoft.SqlServer.Server;
using AdamMachanic.QueryTools;
using System.Threading;

[Serializable]
[Microsoft.SqlServer.Server.SqlUserDefinedAggregate(Format.Native)]
public struct IntervalAgg_ReadOnly_MoreParams
{
    private int rowCount;

    public void Init()
    {
        rowCount = 0;
    }

    public void Accumulate(
        SqlDateTime start,
        SqlDateTime end,
        SqlInt32 StayId,
        SqlInt32 HotelId,
        SqlString HotelName,
        SqlString AddressLine1,
        SqlString AddressLine2,
        SqlString City,
        SqlString StateProvince,
        SqlString PostalCode,
        SqlString CountryRegion,
        SqlInt32 NumberOfRooms)
    {
        rowCount++;
    }

    public void Merge(IntervalAgg_ReadOnly_MoreParams Group)
    {
        this.rowCount += Group.rowCount;
    }

    public SqlInt32 Terminate()
    {
        return (rowCount);
    }
}
