using System;
using System.Data;
using System.Data.SqlClient;
using System.Data.SqlTypes;
using Microsoft.SqlServer.Server;
using AdamMachanic.QueryTools;
using System.Threading;

[Serializable]
[Microsoft.SqlServer.Server.SqlUserDefinedAggregate(Format.Native)]
public struct IntervalAgg
{
    //collection of IntervalCounters - one per active thread
    private static readonly BoundlessArray<intervals.IntervalCounter> intervalCounters = 
        new BoundlessArray<intervals.IntervalCounter>();

    //something for Native serialization to chew on
    private byte x;

    public static intervals.IntervalCounter counter
    {
        get
        {
            return (intervalCounters[Thread.CurrentThread.ManagedThreadId]);
        }

        set
        {
            intervalCounters[Thread.CurrentThread.ManagedThreadId] = value;
        }
    }


    public void Init()
    {
        counter = new intervals.IntervalCounter();
    }

    public void Accumulate(
        SqlDateTime start,
        SqlDateTime end,
        //Row number is not used, but will force the query processor to pass things in the right order
        SqlInt32 rowNum)
    {
        counter.Accumulate(start.Value, end.Value);
    }

    public void Merge(IntervalAgg Group)
    {
        throw new InvalidOperationException("Merging not allowed with IntervalAgg; please eliminate partial aggregation");
    }

    public SqlInt32 Terminate()
    {
        return (0);
    }
}
