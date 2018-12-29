using System;
using System.Collections.Generic;
using System.Threading;

namespace AdamMachanic.QueryTools
{
    public partial class QueryParallelizer<T>
    {
        /// <summary>
        /// This is an internal class designed to buffer output rows with a minimum of contention between 
        /// writers and the reader thread. It uses low-lock techniques in order to process sets of rows as
        /// quickly as possible. 
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
        class roundRobinBuffer
        {
            private readonly long bufferSize;
            private readonly itemPackage[] buffers;
            private readonly itemPackage blank;

            public roundRobinBuffer(long bufferSize)
            {
                this.bufferSize = bufferSize;
                this.buffers = new itemPackage[bufferSize];
                this.blank = new itemPackage(new T[0] {}, 0);

                for (long i = 0; i < bufferSize; i++)
                {
                    buffers[i] = blank;
                }

                readLocation = -1;
                writeLocation = -1;
            }

            long readLocation;
            long writeLocation;

            public long GetReadLocation()
            {
                return (Math.Abs(Interlocked.Increment(ref this.readLocation) % bufferSize));
            }

            public long GetWriteLocation()
            {
                return (Math.Abs(Interlocked.Increment(ref this.writeLocation) % bufferSize));
            }

            public bool Write(long location, itemPackage value)
            {
                return (
                    (this.blank) == Interlocked.CompareExchange<itemPackage>(ref buffers[location], value, this.blank));
            }

            public bool Read(long location, out itemPackage value)
            {
                return (
                    (this.blank) != (value = Interlocked.Exchange<itemPackage>(ref buffers[location], this.blank)));
            }
        }
    }
}
