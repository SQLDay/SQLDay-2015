using System;
using System.Collections.Generic;
using System.Data;
using System.Threading;
using System.Data.SqlClient;

namespace AdamMachanic.QueryTools
{
    public partial class QueryParallelizer<T>
    {
        /// <summary>
        /// This is an internal class that implements bulk load operations
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
        class bulkThread
        {
            public bulkThread(
                //For the BulkCopy component
                string connectionString,
                string destinationTable,
                SqlBulkCopyOptions copyOptions,
                int batchSize,
                SqlBulkCopyColumnMappingCollection columnMap,

                //for the internalDataReader
                int fieldCount,
                BulkCopyMappingDelegate dataMap,
                roundRobinBuffer bulkRows,
                ManualResetEvent bulkCompletionEvent,
                
                bool impersonateCaller,
                IntPtr callerIdentityToken,
                threadMonitor mainThreadMonitor)
            {
                this.connectionString = connectionString;
                this.destinationTable = destinationTable;
                this.copyOptions = copyOptions;
                this.batchSize = batchSize;
                this.columnMap = columnMap;
                this.impersonateCaller = impersonateCaller;
                this.callerIdentityToken = callerIdentityToken;

                Thread t = new Thread(new ThreadStart(this.doWork));
                //t.Name = "QueryParallelizer: Bulk Worker Thread (" + this.destinationTable + ")";
                this.worker = t;

                this.bulkDataReader = new internalDataReader(
                    fieldCount,
                    dataMap,
                    bulkRows,
                    bulkCompletionEvent,
                    this.worker,
                    mainThreadMonitor);
            }

            private readonly string connectionString;
            private readonly string destinationTable;
            private readonly SqlBulkCopyOptions copyOptions;
            private readonly int batchSize;
            private readonly SqlBulkCopyColumnMappingCollection columnMap;
            private readonly internalDataReader bulkDataReader;
            private readonly Thread worker;
            private readonly bool impersonateCaller;
            private readonly IntPtr callerIdentityToken;

            private monitorThread monitor;

            private bool workComplete;
            public bool WorkComplete
            {
                get
                {
                    return (this.workComplete);
                }
            }

            private volatile bool threadFinishing = false;
            public bool ThreadFinishing
            {
                get
                {
                    return (this.threadFinishing);
                }
            }

            public void Start(monitorThread monitor)
            {
                this.monitor = monitor;
                this.workComplete = false;

                if (
                    !(this.worker.IsAlive) &&
                    !(this.bulkDataReader.ThreadCanceled))
                {
                    this.worker.Start();
                }
            }

            public void Cancel(int severity)
            {
                this.bulkDataReader.Cancel(severity);
            }

            public void doWork()
            {
                System.Security.Principal.WindowsImpersonationContext callerContext = null;

                try
                {
                    if (impersonateCaller)
                    {
                        System.Security.Permissions.SecurityPermission secPerm =
                            new System.Security.Permissions.SecurityPermission(System.Security.Permissions.PermissionState.Unrestricted);
                        secPerm.Assert();

                        //sometimes the first attempt will fail, due to what is apparently a CLR bug. 
                        //Retry several times if necessary, and sleep to let things clear out.

                        int impersonationAttempt = 0;

                        while (impersonationAttempt < 25)
                        {
                            try
                            {
                                callerContext = System.Security.Principal.WindowsIdentity.Impersonate(callerIdentityToken);
                            }
                            catch (ArgumentException)
                            {
                                if (impersonationAttempt == 24)
                                    throw;
                                else
                                {
                                    Thread.Sleep(250);
                                    impersonationAttempt++;
                                    continue;
                                }
                            }

                            impersonationAttempt = 25;
                        }

                        System.Security.CodeAccessPermission.RevertAll();
                    }

                    SqlClientPermission sqlPerm =
                        new SqlClientPermission(System.Security.Permissions.PermissionState.Unrestricted);
                    sqlPerm.Assert();

                    using (SqlBulkCopy bc = new SqlBulkCopy(connectionString, copyOptions))
                    {
                        bc.DestinationTableName = destinationTable;
                        bc.BulkCopyTimeout = 0;
                        bc.BatchSize = batchSize;

                        if (columnMap != null)
                        {
                            foreach (SqlBulkCopyColumnMapping cm in columnMap)
                            {
                                bc.ColumnMappings.Add(cm);
                            }
                        }

                        bc.WriteToServer(this.bulkDataReader);
                    }
                }
                catch (Exception ex)
                {
                    Exception workerEx = new Exception("Exception occurred in worker", ex);
                    monitor.WorkerThreadException = workerEx;
                }
                finally
                {
                    this.threadFinishing = true;

                    if (callerContext != null)
                        callerContext.Undo();

                    monitor.SetWorkerCompleted(true);
                    this.workComplete = true;
                }
            }

            private class internalDataReader : IDataReader
            {
                private readonly int fieldCount;
                private readonly BulkCopyMappingDelegate dataMap;
                private readonly roundRobinBuffer bulkRows;
                private readonly ManualResetEvent bulkCompletionEvent;
                private readonly Thread worker;
                private readonly threadMonitor mainThreadMonitor;

                private itemPackage result = null;
                private int currentResult = -1;
                private bool monitorExit = false;

                const int YIELD_INTERVAL = 100;
                const int YIELD_OVERFLOW_BUFFER = int.MaxValue - 250;
                int nextYield = System.Environment.TickCount + YIELD_INTERVAL;

                private volatile bool threadCanceled = false;
                public bool ThreadCanceled
                {
                    get 
                    {
                        if (nextYield < System.Environment.TickCount)
                        {
                            System.Threading.Thread.Sleep(0);
                            nextYield = System.Environment.TickCount;
                            nextYield = (nextYield > YIELD_OVERFLOW_BUFFER) ? int.MinValue : nextYield + YIELD_INTERVAL;
                        }

                        return (this.threadCanceled || !(mainThreadMonitor.IsThreadAlive)); 
                    }
                }

                public void Cancel(int severity)
                {
                    this.threadCanceled = true;

                    System.Security.Permissions.SecurityPermission secPerm =
                        new System.Security.Permissions.SecurityPermission(System.Security.Permissions.PermissionState.Unrestricted);
                    secPerm.Assert();

                    if (severity == 2)
                    {
                        try
                        {
                            if (this.worker.IsAlive)
                                this.worker.Interrupt();
                        }
                        catch
                        {
                        }
                    }
                    else if (severity > 2)
                    {
                        if (this.worker.IsAlive)
                        {
                            try
                            {
                                this.worker.Abort();
                            }
                            catch
                            {
                            }
                        }
                    }
                }

                public internalDataReader(
                    int fieldCount,
                    BulkCopyMappingDelegate dataMap,
                    roundRobinBuffer bulkRows,
                    ManualResetEvent bulkCompletionEvent,
                    Thread worker,
                    threadMonitor mainThreadMonitor)
                {
                    this.fieldCount = fieldCount;
                    this.dataMap = dataMap;
                    this.bulkRows = bulkRows;
                    this.bulkCompletionEvent = bulkCompletionEvent;
                    this.worker = worker;
                    this.mainThreadMonitor = mainThreadMonitor;
                }

                public void Close()
                {
                    throw new NotImplementedException();
                }

                public int Depth
                {
                    get { throw new NotImplementedException(); }
                }

                public DataTable GetSchemaTable()
                {
                    throw new NotImplementedException();
                }

                public bool IsClosed
                {
                    get { throw new NotImplementedException(); }
                }

                public bool NextResult()
                {
                    throw new NotImplementedException();
                }

                public bool Read()
                {
                    while (true)
                    {
                        if (result == null)
                        {
                            long readLoc = bulkRows.GetReadLocation();

                            while (true)
                            {
                                if (bulkRows.Read(readLoc, out result))
                                {
                                    currentResult = -1;
                                    break;
                                }
                                else
                                {
                                    if (monitorExit)
                                    {
                                        //need to send back a message to the monitor thread
                                        return (false);
                                    }
                                    else
                                    {
                                        //no more rows to grab and we're here? might be time to exit.
                                        if (bulkCompletionEvent.WaitOne(1))
                                            monitorExit = true;

                                        //if the thread canceled flag is set, return true, so we can force an exception
                                        if (ThreadCanceled)
                                            return (true);
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

                public int RecordsAffected
                {
                    get { throw new NotImplementedException(); }
                }

                public void Dispose()
                {
                    throw new NotImplementedException();
                }

                public int FieldCount
                {
                    get { return (this.fieldCount); }
                }

                public bool GetBoolean(int i)
                {
                    throw new NotImplementedException();
                }

                public byte GetByte(int i)
                {
                    throw new NotImplementedException();
                }

                public long GetBytes(int i, long fieldOffset, byte[] buffer, int bufferoffset, int length)
                {
                    throw new NotImplementedException();
                }

                public char GetChar(int i)
                {
                    throw new NotImplementedException();
                }

                public long GetChars(int i, long fieldoffset, char[] buffer, int bufferoffset, int length)
                {
                    throw new NotImplementedException();
                }

                public IDataReader GetData(int i)
                {
                    throw new NotImplementedException();
                }

                public string GetDataTypeName(int i)
                {
                    throw new NotImplementedException();
                }

                public DateTime GetDateTime(int i)
                {
                    throw new NotImplementedException();
                }

                public decimal GetDecimal(int i)
                {
                    throw new NotImplementedException();
                }

                public double GetDouble(int i)
                {
                    throw new NotImplementedException();
                }

                public Type GetFieldType(int i)
                {
                    throw new NotImplementedException();
                }

                public float GetFloat(int i)
                {
                    throw new NotImplementedException();
                }

                public Guid GetGuid(int i)
                {
                    throw new NotImplementedException();
                }

                public short GetInt16(int i)
                {
                    throw new NotImplementedException();
                }

                public int GetInt32(int i)
                {
                    throw new NotImplementedException();
                }

                public long GetInt64(int i)
                {
                    throw new NotImplementedException();
                }

                public string GetName(int i)
                {
                    throw new NotImplementedException();
                }

                public int GetOrdinal(string name)
                {
                    throw new NotImplementedException();
                }

                public string GetString(int i)
                {
                    throw new NotImplementedException();
                }

                public object GetValue(int i)
                {
                    if (ThreadCanceled)
                        //Force an exception to occur inside the SqlBulkCopy class in order to abort it
                        return (null);
                    else
                        return dataMap(result.itemList[currentResult], i);
                }

                public int GetValues(object[] values)
                {
                    throw new NotImplementedException();
                }

                public bool IsDBNull(int i)
                {
                    throw new NotImplementedException();
                }

                public object this[string name]
                {
                    get { throw new NotImplementedException(); }
                }

                public object this[int i]
                {
                    get { throw new NotImplementedException(); }
                }
            }

        }
    }
}
