using System;
using System.Threading;

namespace AdamMachanic.QueryTools
{
    public partial class QueryParallelizer<T>
    {
        /// <summary>
        /// This class implements an internal thread used to monitor the workers and the main thread. The
        /// monitor wakes up every 750ms to make sure that everything is still running properly. Should there
        /// be any issues--such as a run-time exception on one of the worker threads--the monitor will alert
        /// the other workers as well as the main thread in order to shut everything down as cleanly as possible.
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
        private class monitorThread
        {
            public monitorThread(
                threadMonitor mainThreadMonitor,
                ManualResetEvent initializationEvent,
                ManualResetEvent completionEvent,
                ManualResetEvent bulkCompletitionEvent,
                workerThread[] workers,
                bulkThread[] bulkWorkers,
                workPackage[] workPackages)
            {
                this.mainThreadMonitor = mainThreadMonitor;
                this.initializationEvent = initializationEvent;
                this.completionEvent = completionEvent;
                this.bulkCompletionEvent = bulkCompletitionEvent;
                this.workers = workers;
                this.bulkWorkers = bulkWorkers;
                this.workPackages = workPackages;

                this.numWorkerThreads = workPackages.LongLength;
                this.numTotalThreads = workPackages.LongLength + bulkWorkers.LongLength;
            }

            private readonly threadMonitor mainThreadMonitor;
            private readonly ManualResetEvent initializationEvent;
            private readonly ManualResetEvent completionEvent;
            private readonly ManualResetEvent bulkCompletionEvent;

            private readonly long numWorkerThreads;
            private readonly long numTotalThreads;
            private readonly workerThread[] workers;
            private readonly bulkThread[] bulkWorkers;
            private readonly workPackage[] workPackages;

            private AutoResetEvent workerCompletedEvent = new AutoResetEvent(false);
            private long nextWorkerThread = -1;
            private long numFinishedThreads = 0;

            private volatile Exception workerThreadException;
            public Exception WorkerThreadException
            {
                get
                {
                    lock(completionEvent)
                        return (this.workerThreadException);
                }

                set
                {
                    lock (completionEvent)
                    {
                        //only honor the first exception
                        if (this.workerThreadException == null)
                            this.workerThreadException = value;
                    }
                }
            }

            public void SetWorkerCompleted(bool incrementCompletionCounter)
            {
                if (incrementCompletionCounter)
                    Interlocked.Increment(ref numFinishedThreads);

                workerCompletedEvent.Set();
            }

            public workPackage GetNextWorkPackage()
            {
                long nextThread = Interlocked.Increment(ref nextWorkerThread);

                if (nextThread < numWorkerThreads)
                {
                    return (workPackages[nextThread]);
                }
                else
                    return null;
            }

            private void cancelAllThreads(
                int severity)
            {
                //Cycle through each of the workers. If the work is not yet finished, send a cancel message (or worse)
                //If the work is finished, set the reference to NULL so that the GC can clean up any mess we've created
                //severity 5 is a special final cleanup pass
                
                while (severity <= 5)
                {
                    bool workerStillAlive = false;

                    for (int i = 0; i < workers.Length; i++)
                    {
                        try
                        {
                            if (workers[i] != null)
                            {
                                if (
                                    !(workers[i].WorkComplete) &&
                                    !(workers[i].ThreadFinishing) &&
                                    severity < 5)
                                {
                                    workerStillAlive = true;
                                    try
                                    {
                                        workers[i].Cancel(severity);
                                    }
                                    catch
                                    {
                                    }
                                }
                                else
                                    workers[i] = null;
                            }
                        }
                        catch
                        {
                        }
                    }

                    for (int i = 0; i < bulkWorkers.Length; i++)
                    {
                        try
                        {
                            if (bulkWorkers[i] != null)
                            {
                                if (!bulkWorkers[i].WorkComplete &&
                                    severity < 5)
                                {
                                    workerStillAlive = true;
                                    try
                                    {
                                        bulkWorkers[i].Cancel(severity);
                                    }
                                    catch
                                    {
                                    }
                                }
                                else
                                    bulkWorkers[i] = null;
                            }
                        }
                        catch
                        {
                        }
                    }

                    if (workerStillAlive)
                    {
                        //wait 10 * severity seconds before trying to cancel at the next severity
                        Thread.Sleep(10000 * severity);
                    }

                    severity++;
                }

                GC.Collect(int.MaxValue, GCCollectionMode.Forced);
            }

            public void SetupMonitorThread()
            {
                try
                {
                    Thread.BeginThreadAffinity();

                    //start the workers, but stagger them by sleeping for 50ms in between each start
                    //check both before and after the sleep to make sure that nothing has gone wrong in the meantime
                    
                    int workCounter = 0;
                    int bulkCounter = 0;

                    while 
                        (
                            (workCounter < workers.Length &&
                             Interlocked.Read(ref nextWorkerThread) < numWorkerThreads
                            ) ||
                        bulkCounter < bulkWorkers.Length)
                    {
                        if (workCounter < workers.Length)
                        {
                            if (!(mainThreadMonitor.IsThreadAlive) ||
                                workerThreadException != null)
                                break;

                            if (workCounter > 0)
                            {
                                //How long should we wait before spinning up a new thread?
                                Thread.Sleep(50);

                                if (!(mainThreadMonitor.IsThreadAlive) ||
                                    workerThreadException != null)
                                    break;
                            }

                            workers[workCounter].Start(this);

                            workCounter++;
                        }

                        //stagger the starts so that there are some bulk workers available to pick up work done by the first workers

                        if (bulkCounter < bulkWorkers.Length)
                        {
                            if (!(mainThreadMonitor.IsThreadAlive) ||
                                workerThreadException != null)
                                break;

                            Thread.Sleep(50);

                            if (!(mainThreadMonitor.IsThreadAlive) ||
                                workerThreadException != null)
                                break;

                            bulkWorkers[bulkCounter].Start(this);

                            bulkCounter++;
                        }
                    }

                    //set this event so that the main thread knows that initialization is complete
                    initializationEvent.Set();

                    //start monitoring all of the threads
                    while (true)
                    {
                        long finishedThreads = Interlocked.Read(ref numFinishedThreads);

                        if (finishedThreads == numWorkerThreads)
                            bulkCompletionEvent.Set();

                        if (finishedThreads == numTotalThreads)
                            break;

                        //if the main thread is gone or a worker has thrown an exception... abort
                        if (!(mainThreadMonitor.IsThreadAlive) ||
                            workerThreadException != null)
                            break;

                        workerCompletedEvent.WaitOne(500);
                    }
                }
                catch (Exception ex)
                {
                    Exception monitorEx = new Exception("Exception occurred in monitor thread", ex);
                    WorkerThreadException = monitorEx;
                }
                finally
                {
                    //in case initialization is still running
                    initializationEvent.Set();

                    //clean up the worker threads, as necessary
                    if (!(mainThreadMonitor.IsThreadAlive) ||
                        workerThreadException != null)
                        cancelAllThreads(1);
                    else
                        cancelAllThreads(5);

                    //signal the completed handle so that the main thread can exit
                    completionEvent.Set();

                    Thread.EndThreadAffinity();
                }
            }
        }
    }
}