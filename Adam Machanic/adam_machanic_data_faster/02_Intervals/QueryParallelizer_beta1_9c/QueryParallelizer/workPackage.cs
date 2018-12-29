using System;
using System.Collections.Generic;
using System.Text;

namespace AdamMachanic.QueryTools
{
    public partial class QueryParallelizer<T>
    {
        /// <summary>
        /// This internal class is used to buffer work to be done, in the form of integer subranges.
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
        private class workPackage
        {
            public workPackage(int rangeMinimum, int rangeMaximum)
            {
                this.rangeMinimum = rangeMinimum;
                this.rangeMaximum = rangeMaximum;
            }

            public readonly int rangeMinimum;
            public readonly int rangeMaximum;
        }
    }
}
