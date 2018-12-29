using System;
using System.Data;
using System.Data.SqlClient;
using System.Data.SqlTypes;
using Microsoft.SqlServer.Server;
using System.Collections;

public partial class UserDefinedFunctions
{
    [Microsoft.SqlServer.Server.SqlFunction(
        FillRowMethodName="IntervalValues_Fill", 
        TableDefinition="StartDate DATETIME, EndDate DATETIME, Count INT")]
    public static IEnumerable IntervalValues(SqlInt32 IntervalAggValue)
    {
        foreach (intervals.IntervalCounter.Result r in IntervalAgg.counter.Terminate())
            yield return (r);
    }

    public static void IntervalValues_Fill(
        object o, 
        out SqlDateTime StartDate, 
        out SqlDateTime EndDate, 
        out SqlInt32 Count)
    {
        var r = (intervals.IntervalCounter.Result)o;
        StartDate = r.Start;
        EndDate = r.End;
        Count = r.Count;
    }
};

