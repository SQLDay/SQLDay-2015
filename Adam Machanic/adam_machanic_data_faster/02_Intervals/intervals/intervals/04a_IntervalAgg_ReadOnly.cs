using System;
using System.Data;
using System.Data.SqlClient;
using System.Data.SqlTypes;
using Microsoft.SqlServer.Server;
using AdamMachanic.QueryTools;
using System.Threading;

[Serializable]
[Microsoft.SqlServer.Server.SqlUserDefinedAggregate(Format.Native)]
public struct IntervalAgg_ReadOnly
{
    private int rowCount;

    public void Init()
    {
        rowCount = 0;
    }

    public void Accumulate(
        SqlDateTime start,
        SqlDateTime end)
    {
        rowCount++;
    }

    public void Merge(IntervalAgg_ReadOnly Group)
    {
        this.rowCount += Group.rowCount;
    }

    public SqlInt32 Terminate()
    {
        return (rowCount);
    }
}
