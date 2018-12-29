using System;
using System.Threading;
using System.Data.SqlClient;

namespace AdamMachanic.QueryTools
{
    public partial class QueryParallelizer<T>
    {
        /// <summary>
        /// This class implements the worker logic used to run the query, process the data, and buffer output
        /// rows for delivery back to the caller.
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
        private class workerThread
        {
            public workerThread(
                SqlCommand comm,
                roundRobinBuffer outputRows,
                RowLogicDelegate rowLogic,
                bool reuseConnection,
                int packageSize,
                roundRobinBuffer bulkRows,
                bool impersonateCaller,
                IntPtr callerIdentityToken,
                threadMonitor mainThreadMonitor)
            {
                this.comm = comm;
                this.outputRows = outputRows;
                this.rowLogic = rowLogic;
                this.reuseConnection = reuseConnection;
                this.packageSize = packageSize;
                this.bulkRows = bulkRows;
                this.impersonateCaller = impersonateCaller;
                this.callerIdentityToken = callerIdentityToken;
                this.mainThreadMonitor = mainThreadMonitor;

                Thread t = new Thread(new ThreadStart(this.doWork));
                //t.Name = "QueryParallelizer: Worker Thread (" + comm.CommandText.Substring(0, 50) + ")";
                this.worker = t;
            }

            private readonly SqlCommand comm;
            private readonly roundRobinBuffer outputRows;
            private readonly RowLogicDelegate rowLogic;
            private readonly Thread worker;
            private readonly bool reuseConnection;
            private readonly int packageSize;
            private readonly roundRobinBuffer bulkRows;
            private readonly bool impersonateCaller;
            private readonly IntPtr callerIdentityToken;
            private readonly threadMonitor mainThreadMonitor;

            private monitorThread monitor;
            private T[] itemList = null;
            private int listPosition = 0;

            //this is set when the monitor thread calls Cancel
            private volatile bool threadCanceled = false;
            public bool ThreadCanceled
            {
                get 
                {
                    return (this.threadCanceled || !(mainThreadMonitor.IsThreadAlive)); 
                }
            }

            //this is set when the thread falls into its finally block, and is used to tell the monitor that the thread is cleaning itself up
            private volatile bool threadFinishing = false;
            public bool ThreadFinishing
            {
                get
                {
                    return (this.threadFinishing);
                }
            }

            private bool workComplete;
            public bool WorkComplete
            {
                get
                {
                    return (this.workComplete);
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
                            this.comm.Cancel();
                    }
                    catch
                    {
                    }
                }
                else if (severity == 3)
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
                else if (severity > 3)
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

            public void doWork()
            {
                SqlConnection conn = null;
                System.Security.Principal.WindowsImpersonationContext callerContext = null;

                try
                {
                    Thread.BeginThreadAffinity();

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

                    //set up object for the connection
                    conn = comm.Connection;
                    if (reuseConnection)
                    {
                        conn.Open();
                        comm.Prepare();
                    }

                    while (true)
                    {
                        if (ThreadCanceled)
                            break;

                        //find out if there is some work to do
                        workPackage wp = monitor.GetNextWorkPackage();

                        if (wp == null)
                            break;

                        comm.Parameters[0].Value = wp.rangeMinimum;
                        comm.Parameters[1].Value = wp.rangeMaximum;

                        if (!reuseConnection)
                            conn.Open();

                        //run the query
                        SqlDataReader r = comm.ExecuteReader();

                        if (r.HasRows)
                        {
                            foreach (T row in rowLogic(r))
                            {
                                if (ThreadCanceled)
                                    break;

                                enqueue(row, true);
                            }

                            //tell the enqueue method to send the final set of rows
                            enqueue(default(T), false);
                        }
                        else
                        {
                            //r has no rows
                            //need to call Read() to discover whether an exception occurred
                            r.Read();

                            //an exception may have occurred on a "result" other than the first
                            //need to iterate over all possible results
                            while (r.NextResult())
                                r.Read();
                        }

                        if (reuseConnection)
                            r.Dispose();
                        else
                            conn.Close();

                        monitor.SetWorkerCompleted(true);
                    }
                }
                catch (Exception ex)
                {
                    Exception workerEx = new Exception("Exception occurred in worker", ex);
                    monitor.WorkerThreadException = workerEx;
                    monitor.SetWorkerCompleted(true);
                }
                finally
                {
                    this.threadFinishing = true;

                    comm.Cancel();
                    comm.Dispose();

                    if (conn != null)
                        conn.Dispose();

                    if (callerContext != null)
                        callerContext.Undo();

                    this.workComplete = true;

                    Thread.EndThreadAffinity();
                }
            }

            public void Start(monitorThread monitor)
            {
                this.monitor = monitor;

                if (
                    !(this.worker.IsAlive) &&
                    !(this.ThreadCanceled))
                {
                    this.worker.Start();
                }
            }

            private void enqueue(
                T row,
                bool enqueue)
            {
                if (itemList == null)
                {
                    itemList = new T[packageSize];
                    listPosition = -1;
                }

                if (enqueue)
                    itemList[++listPosition] = row;

                if (
                    listPosition == (packageSize - 1) ||
                    (!enqueue))
                {
                    itemPackage ip = new itemPackage(itemList, listPosition);

                    if (outputRows != null)
                    {
                        long writeLoc = outputRows.GetWriteLocation();

                        while (!ThreadCanceled)
                        {
                            if (outputRows.Write(writeLoc, ip))
                            {
                                itemList = null;
                                break;
                            }
                            else
                                //force a 1ms backoff if the slot is not available
                                Thread.Sleep(1);
                        }
                    }

                    if (bulkRows != null)
                    {
                        long writeLoc = bulkRows.GetWriteLocation();

                        while (!ThreadCanceled)
                        {
                            if (bulkRows.Write(writeLoc, ip))
                            {
                                itemList = null;
                                break;
                            }
                            else
                                //force a 1ms backoff if the slot is not available
                                Thread.Sleep(1);
                        }
                    }
                }
            }
        }
    }
}
