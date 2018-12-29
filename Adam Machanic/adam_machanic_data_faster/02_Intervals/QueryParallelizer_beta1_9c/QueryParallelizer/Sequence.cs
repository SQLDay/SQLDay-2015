using System;
using System.Threading;

namespace AdamMachanic.QueryTools
{
    /// <summary>
    /// This class provides a simple thread-safe wrapper over a 64-bit integer. It is included here 
    /// because it is a generally useful construct that requires that the UNSAFE permission be set on
    /// the host assembly.
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
    public class Sequence
    {
        private long currentValue;

        public Sequence()
            : this(0)
        {
        }

        public Sequence(long startingValue)
        {
            this.currentValue = startingValue;
        }

        public long NextValue()
        {
            return (Interlocked.Increment(ref currentValue));
        }

        public long CurrentValue()
        {
            return (Interlocked.Read(ref currentValue));
        }

        public long Exchange(long newValue)
        {
            return (Interlocked.Exchange(ref currentValue, newValue));
        }

        public bool CompareExchange(long newValue, long testValue)
        {
            return (testValue == Interlocked.CompareExchange(ref currentValue, newValue, testValue));
        }
    }
}
