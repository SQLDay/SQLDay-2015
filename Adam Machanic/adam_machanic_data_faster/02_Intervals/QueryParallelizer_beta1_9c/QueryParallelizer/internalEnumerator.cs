using System;
using System.Collections.Generic;
using System.Threading;
using System.Data.SqlClient;

namespace AdamMachanic.QueryTools
{
    public partial class QueryParallelizer<T> 
    {
        /// <summary>
        /// This is an internal class that implements the enumerator returned by the Process() method on the
        /// public QueryParallelizer class. 
        /// 
        /// License:
        /// 
        /// This code is part of the QueryParallelizer project. You are free to compile the QueryParallelizer for use in educational 
        /// or internal corporate purposes. Outside of your company or institution you are strictly prohibited from sale, reuse, or
        /// redistribution of any part of this code or the compiled QueryParallelizer DLL, in whole or in part, either alone or as 
        /// part of another project, without written consent from Adam Machanic.
        /// 
        /// No warranties are implied regarding the stability or performance of the QueryParallelizer, nor regarding its suitability 
        /// for any project. This code is distributed "as-is" and the author is not responsible for problems that may occur due to 
        /// use or misuse of this code. 
        /// 
        /// (C) 2010 Adam Machanic
        /// amachanic@gmail.com
        /// </summary>
        private class internalEnumerator : IEnumerable<T>, IEnumerator<T>
        {
            //set in the constructor
            private readonly roundRobinBuffer outputRows;
            private readonly ManualResetEvent completionEvent;
            private readonly monitorThread mp;

            //private members
            private itemPackage result = null;
            private int currentResult = -1;
            private bool monitorExit = false;

            public internalEnumerator(
                string query,
                string minVariable,
                string maxVariable,
                int minValue,
                int maxValue,
                int numWorkerThreads,
                RowLogicDelegate rowLogic,
                string targetConnectionString,
                int rowBufferSize,
                int packageSize,
                int batchSize,
                bool reuseConnection,
                BulkCopySettings bulkSettings,
                bool impersonateCaller,
                IntPtr callerIdentityToken,
                SqlParameter[] additionalParameters)
            {
                try
                {
                    Thread.BeginThreadAffinity();

                    threadMonitor mainThreadMonitor = new threadMonitor(System.Threading.Thread.CurrentThread);

                    outputRows = new roundRobinBuffer(rowBufferSize);
                    completionEvent = new ManualResetEvent(false);

                    //buffer that will be shared by the task workers and the bulk workers
                    roundRobinBuffer bulkRows = null;
                    //event that will be shared by the monitor thread and the bulk workers
                    ManualResetEvent bulkCompletionEvent = new ManualResetEvent(false);
                    bool outputRowsToExternalEnumerator = true;

                    List<bulkThread> bulkWorkers = new List<bulkThread>();
                    if (bulkSettings != null)
                    {
                        outputRowsToExternalEnumerator = bulkSettings.OutputRowsToExternalEnumerator;
                        bulkRows = new roundRobinBuffer(rowBufferSize);

                        for (int i = 1; i <= bulkSettings.NumThreads; i++)
                        {
                            bulkWorkers.Add(
                                new bulkThread(
                                    bulkSettings.ConnectionString,
                                    bulkSettings.DestinationTable,
                                    bulkSettings.CopyOptions,
                                    bulkSettings.BatchSize,
                                    bulkSettings.ColumnMap,
                                    bulkSettings.FieldCount,
                                    bulkSettings.DataMap,
                                    bulkRows,
                                    bulkCompletionEvent,
                                    impersonateCaller,
                                    callerIdentityToken,
                                    mainThreadMonitor));
                        }
                    }

                    List<workerThread> workers = new List<workerThread>();
                    List<workPackage> workPackages = new List<workPackage>();

                    int minValueThread;
                    int maxValueThread;
                    long range = ((long)maxValue - (long)minValue + 1);

                    //initialize the worker threads
                    if (batchSize <= 0)
                    {
                        //if there are fewer threads than values in the range, do a simple one-to-one distribution
                        if (range < numWorkerThreads)
                        {
                            for (int i = minValue; i <= maxValue; i++)
                                workPackages.Add(new workPackage(i, i));
                        }
                        else
                        {
                            for (int i = 0; i < numWorkerThreads; i++)
                            {
                                //determine the correct min and max values per thread
                                minValueThread = (int)((long)minValue + ((range / (long)numWorkerThreads) * (long)i));
                                maxValueThread = ((i + 1) == numWorkerThreads) ? maxValue : (int)((long)minValue - 1 + ((range / (long)numWorkerThreads) * (long)(i + 1)));

                                //at edges we may have more threads than can be used - ignore them
                                if (maxValueThread < int.MaxValue && minValueThread > int.MinValue)
                                {
                                    if (maxValueThread == (minValueThread - 1))
                                    {
                                        numWorkerThreads--;
                                        continue;
                                    }
                                }

                                workPackages.Add(new workPackage(minValueThread, maxValueThread));
                            }
                        }
                    }
                    else
                    {
                        minValueThread = minValue;
                        maxValueThread = minValueThread + (batchSize - 1);

                        do
                        {
                            if (maxValueThread > maxValue)
                                maxValueThread = maxValue;

                            workPackages.Add(new workPackage(minValueThread, maxValueThread));

                            if (maxValueThread == maxValue)
                                break;

                            int tempMaxValue = maxValueThread;

                            minValueThread = maxValueThread + 1;
                            maxValueThread = minValueThread + (batchSize - 1);

                            //has an overflow occurred?
                            if (maxValueThread < tempMaxValue)
                                maxValueThread = maxValue;

                        } while (minValueThread <= maxValue);
                    }

                    for (int j = 0; j < ((workPackages.Count < numWorkerThreads) ? workPackages.Count : numWorkerThreads); j++)
                    {
                        SqlConnection conn = new SqlConnection((targetConnectionString == null) ? ConnectionBuilder.LoopbackConnectionString : targetConnectionString);
                        SqlCommand comm = conn.CreateCommand();
                        comm.CommandText = query;
                        comm.CommandTimeout = 0;

                        comm.Parameters.Add(minVariable, System.Data.SqlDbType.Int);
                        comm.Parameters.Add(maxVariable, System.Data.SqlDbType.Int);

                        if (additionalParameters != null)
                        {
                            foreach (SqlParameter param in additionalParameters)
                                comm.Parameters.Add(param);
                        }

                        //spin up worker thread, pass in the required args
                        workers.Add(
                            new workerThread(
                                comm,
                                outputRowsToExternalEnumerator ? outputRows : null,
                                rowLogic,
                                reuseConnection,
                                packageSize,
                                bulkRows,
                                impersonateCaller,
                                callerIdentityToken,
                                mainThreadMonitor));
                    }

                    //Event that will be signaled when the monitor is initialized
                    ManualResetEvent initializationEvent = new ManualResetEvent(false);

                    //initialize the monitor thread
                    mp = new monitorThread(
                        mainThreadMonitor,
                        initializationEvent,
                        completionEvent,
                        bulkCompletionEvent,
                        workers.ToArray(),
                        bulkWorkers.ToArray(),
                        workPackages.ToArray());

                    var t = new Thread(new ThreadStart(mp.SetupMonitorThread));
                    //t.Name = "QueryParallelizer: Monitor Thread";

                    //start the monitor thread
                    t.Start();

                    //Wait up to 20 seconds + [number of workers] seconds * 2 for initialization
                    int waitInterval = 20000 + ((workers.Count + bulkWorkers.Count) * 2000);

                    bool initialized = initializationEvent.WaitOne(waitInterval);

                    if (mp.WorkerThreadException != null)
                        throw mp.WorkerThreadException;

                    if (!initialized)
                        throw new Exception(String.Format("Monitor thread failed to initialize within {0} milliseconds", waitInterval));
                }
                finally
                {
                    Thread.EndThreadAffinity();
                }
            }

            #region IEnumerable Members

            public IEnumerator<T> GetEnumerator()
            {
                return (this);
            }

            System.Collections.IEnumerator System.Collections.IEnumerable.GetEnumerator()
            {
                return (this);
            }

            #endregion

            #region IEnumerator Members

            public T Current
            {
                get { return (this.result.itemList[currentResult]); }
            }

            object System.Collections.IEnumerator.Current
            {
                get { return (this.result.itemList[currentResult]); }
            }

            public bool MoveNext()
            {
                while (true)
                {
                    if (result == null)
                    {
                        long readLoc = outputRows.GetReadLocation();

                        while (true)
                        {
                            if (outputRows.Read(readLoc, out result))
                            {
                                currentResult = -1;
                                break;
                            }
                            else
                            {
                                if (monitorExit)
                                {
                                    return (false);
                                }
                                else
                                {
                                    //no more rows to grab and we're here? might be time to exit.
                                    if (completionEvent.WaitOne(1))
                                        monitorExit = true;

                                    if (mp.WorkerThreadException != null)
                                        throw mp.WorkerThreadException;

                                    Thread.Sleep(0);
                                }
                            }
                        }
                    }

                    if (++currentResult > result.itemCount)
                    {
                        result = null;
                        continue;
                    }
                    else
                    {
                        return (true);
                    }
                }
            }

            public void Reset()
            {
                throw new NotImplementedException();
            }

            #endregion

            #region IDisposable Members

            public void Dispose()
            {
                this.mp.SetWorkerCompleted(false);
            }

            #endregion
        }
    }
}
