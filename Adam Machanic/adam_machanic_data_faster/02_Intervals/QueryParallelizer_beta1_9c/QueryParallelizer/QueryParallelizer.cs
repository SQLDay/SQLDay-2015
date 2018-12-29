using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using Microsoft.SqlServer.Server;

namespace AdamMachanic.QueryTools
{
    /// <summary>
    /// QueryParallelizer is designed to programmatically invoke parallel processes using SQL Server's SQLCLR 
    /// components. It works by splitting a range of integers into equal subranges based on either a batch
    /// size or a fixed number of threads on which to operate. Row manipulation logic is handled via one of
    /// two delegate types.
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
    /// <typeparam name="T">
    /// The generic type must be a class that exposes a public constructor, and will be the output type 
    /// of the enumerator generated via the QueryParallelizer.Process() method.
    /// </typeparam>
    public partial class QueryParallelizer<T> 
    {
        //input parameter values
        private readonly string query;
        private readonly string minVariable;
        private readonly string maxVariable;
        private readonly int minValue;
        private readonly int maxValue;
        private readonly int numWorkerThreads;
        private readonly RowLogicDelegate rowLogic;

        //private members
        private bool isProcessing = false;

        //settable values
        private string targetConnectionString;
        private int rowBufferSize = 100;
        private int packageSize = 100;
        private int batchSize = 0;
        private bool reuseConnection = false;
        private BulkCopySettings bulkSettings = null;
        private bool impersonateCaller = false;
        private SqlParameter[] additionalParameters = null;

        /// <summary>
        /// Can be used to override the default loopback connection string, in order to manipulate
        /// data from a different server than the one on which the request originates
        /// </summary>
        public string TargetConnectionString
        {
            get
            {
                return (this.targetConnectionString);
            }

            set
            {
                if (isProcessing)
                    throw new Exception("Connection string can only be set prior to processing");

                this.targetConnectionString = value;
            }
        }

        /// <summary>
        /// Can be set to override the size of the internal row buffer. Each buffer contains a "package"
        /// of rows (see the PackageSize property). By default the buffer can hold 100 row packages.
        /// </summary>
        public int RowBufferSize
        {
            get
            {
                return (this.rowBufferSize);
            }

            set
            {
                if (isProcessing)
                    throw new Exception("Row buffer size can only be set prior to processing");

                if (value <= 0)
                    throw new Exception("Row buffer size must be greater than or equal to 1");

                this.rowBufferSize = value;
            }
        }

        /// <summary>
        /// Can be used to override the size of the row "packages" used to contain rows in the row buffer. 
        /// By default each package holds 100 rows waiting to be enumerated.
        /// </summary>
        public int PackageSize
        {
            get
            {
                return (this.packageSize);
            }

            set
            {
                if (isProcessing)
                    throw new Exception("Package size can only be set prior to processing");

                if (value <= 0)
                    throw new Exception("Package size must be greater than or equal to 1");

                this.packageSize = value;
            }
        }

        /// <summary>
        /// The default batch size is 0, which means that the input integer range will be split equally across
        /// the number of worker threads. If this property is set to a value greater than zero, the input range
        /// will instead be split into a number of subranges based on the batch size. Each worker thread will
        /// be responsible for processing one or more of these smaller batches.
        /// </summary>
        public int BatchSize
        {
            get
            {
                return (this.batchSize);
            }

            set
            {
                if (isProcessing)
                    throw new Exception("Batch size can only be set prior to processing");

                this.batchSize = value;
            }
        }

        /// <summary>
        /// When the BatchSize property is set to a nonzero value, a given worker thread may be reused to process
        /// many batches (integer ranges). By default, the database connection will be closed and re-opened 
        /// on each iteration. In order to avoid the cost of re-acquiring the connection from the pool, this
        /// property can be set to true and a single connection will be held for the lifetime of each worker.
        /// </summary>
        public bool ReuseConnection
        {
            get
            {
                return (this.reuseConnection);
            }

            set
            {
                if (isProcessing)
                    throw new Exception("Connection reuse can only be set prior to processing");

                this.reuseConnection = value;
            }
        }

        /// <summary>
        /// Collection of settings for using the bulk copy component
        /// </summary>
        public BulkCopySettings BulkSettings
        {
            get
            {
                return (this.bulkSettings);
            }

            set
            {
                if (isProcessing)
                    throw new Exception("Bulk copy settings can only be set prior to processing");

                this.bulkSettings = value;
            }
        }

        /// <summary>
        /// By default, threads running under the SQLCLR will run in the context of the SQL Server service
        /// account. It may be useful to instead run under the context of the caller. This option handles the
        /// various details needed to make that happen.
        /// </summary>
        public bool ImpersonateCaller
        {
            get
            {
                return (this.impersonateCaller);
            }

            set
            {
                if (!(SqlContext.IsAvailable))
                    throw new Exception("Impersonation is only supported when running in a SQL Server process");

                System.Security.Permissions.SecurityPermission secPerm =
                    new System.Security.Permissions.SecurityPermission(System.Security.Permissions.PermissionState.Unrestricted);
                secPerm.Assert();

                if (null == SqlContext.WindowsIdentity)
                    throw new Exception("Impersonation is not supported with SQL Server logins; you must use integrated authentication");
                    
                if (isProcessing)
                    throw new Exception("Impersonation can only be set prior to processing");

                this.impersonateCaller = value;
            }
        }

        /// <summary>
        /// Additional parameters to be passed to the query at run time
        /// </summary>
        public SqlParameter[] AdditionalParameters
        {
            get
            {
                return (this.additionalParameters);
            }

            set
            {
                if (isProcessing)
                    throw new Exception("Parameters can only be set prior to processing");

                //deep copy the parameters to avoid having them change due to an external reference
                SqlParameter[] copiedParams = new SqlParameter[value.Length];
                for (int i = 0; i < value.Length; i++)
                {
                    copiedParams[i] = (SqlParameter)(((ICloneable)value[i]).Clone());
                }

                this.additionalParameters = copiedParams;
            }
        }

        /// <summary>
        /// This delegate is used to define the logic that manipulates rows from the data reader and produces
        /// instances of the output object shape.
        /// </summary>
        /// <param name="inputData">
        /// The raw SqlDataReader associated with the input set.
        /// </param>
        /// <returns>
        /// The return value is a collection of output rows, or an empty collection if there are no rows to be
        /// output. The collection can be sent back in a single block or rows can be streamed back using the
        /// yield return pattern.
        /// </returns>
        public delegate IEnumerable<T> RowLogicDelegate(
            System.Data.SqlClient.SqlDataReader inputData);

        /// <summary>
        /// This delegate is used to define a map between data in the QueryParallelizer's generic type 
        /// and a column ordinal position. It is used inside of the bulk copy component.
        /// </summary>
        /// <param name="row">The object representing the current output row being processed</param>
        /// <param name="columnOrdinal">The ordinal position of the column in the base table</param>
        /// <returns>The data for the given row based on the requested column ordinal position</returns>
        public delegate object BulkCopyMappingDelegate(
            T row,
            int columnOrdinal);

        /// <summary>
        /// Options for doing bulk copy
        /// </summary>
        public class BulkCopySettings
        {
            //required
            public readonly string DestinationTable;
            public readonly int FieldCount;
            public readonly BulkCopyMappingDelegate DataMap;
            public readonly bool OutputRowsToExternalEnumerator;
            public readonly int NumThreads;

            //optional
            public readonly string ConnectionString;
            public readonly SqlBulkCopyOptions CopyOptions = SqlBulkCopyOptions.Default;
            public readonly int BatchSize = 0;
            public readonly SqlBulkCopyColumnMappingCollection ColumnMap;

            /// <summary>
            /// Constructor for BulkCopySettings class
            /// </summary>
            /// <param name="DestinationTable">Table into which the bulk copy should be done</param>
            /// <param name="FieldCount">Number of columns that will be copied into the destination table</param>
            /// <param name="DataMap">
            /// Delegate that maps fields of the generic type of the QueryParallelizer instance to ordinal positions
            /// </param>
            /// <param name="OutputRowsToExternalEnumerator">
            /// If true, the external enumerator will output the same rows that are processed by the bulk copy component.
            /// If false, the rows will only be output via the bulk component, and the external enumerator will output
            /// an empty result.
            /// </param>
            /// <param name="NumThreads">Number of parallel threads to use for the bulk copy operation</param>
            /// <param name="ConnectionString">
            /// Connection string for the destination table. If left null, the loopback connection provider will be used
            /// </param>
            public BulkCopySettings(
                string destinationTable,
                int fieldCount,
                BulkCopyMappingDelegate dataMap,
                bool outputRowsToExternalEnumerator,
                int numThreads,
                string connectionString)
            {
                if (numThreads < 1 || numThreads > 32)
                    throw new ArgumentException("Number of bulk copy threads must be between 1 and 32");

                this.DestinationTable = destinationTable;
                this.FieldCount = fieldCount;
                this.DataMap = dataMap;
                this.OutputRowsToExternalEnumerator = outputRowsToExternalEnumerator;
                this.NumThreads = numThreads;

                this.ConnectionString = (connectionString == null) ? ConnectionBuilder.LoopbackConnectionString : connectionString;
            }

            /// <summary>
            /// Constructor for BulkCopySettings class
            /// </summary>
            /// <param name="DestinationTable">Table into which the bulk copy should be done</param>
            /// <param name="FieldCount">Number of columns that will be copied into the destination table</param>
            /// <param name="DataMap">
            /// Delegate that maps fields of the generic type of the QueryParallelizer instance to ordinal positions
            /// </param>
            /// <param name="OutputRowsToExternalEnumerator">
            /// If true, the external enumerator will output the same rows that are processed by the bulk copy component.
            /// If false, the rows will only be output via the bulk component, and the external enumerator will output
            /// an empty result.
            /// </param>
            /// <param name="ConnectionString">
            /// Connection string for the destination table. If left null, the loopback connection provider will be used
            /// </param>
            /// <param name="CopyOptions">
            /// SqlBulkCopyOptions enumeration, used to specify table locking, whether to keep NULLs, and other options
            /// </param>
            /// <param name="BatchSize">Number of rows to transfer per batch. Use 0 for unlimited.</param>
            /// <param name="ColumnMap">
            /// Mapping between the DataMap ordinals and the ordinals of columns in the actual destination table. To be 
            /// used when the column order in the base table is different from that specified by the DataMap, or when there 
            /// are fewer columns in the destination table than those that will be populated by the bulk copy operation. 
            /// Can be left null if not needed.
            /// </param>
            public BulkCopySettings(
                string destinationTable,
                int fieldCount,
                BulkCopyMappingDelegate dataMap,
                bool outputRowsToExternalEnumerator,
                int numThreads,
                string connectionString,
                SqlBulkCopyOptions copyOptions,
                int batchSize,
                SqlBulkCopyColumnMapping[] columnMap)
                : this 
                    (destinationTable,
                    fieldCount,
                    dataMap,
                    outputRowsToExternalEnumerator,
                    numThreads,
                    connectionString)
            {
                this.CopyOptions = copyOptions;
                this.BatchSize = batchSize;

                //create an instance of SqlBulkCopy to grab the ColumnMappingCollection
                SqlBulkCopy bc = new SqlBulkCopy("");
                this.ColumnMap = bc.ColumnMappings;

                if (columnMap != null)
                {
                    foreach (SqlBulkCopyColumnMapping cm in columnMap)
                    {
                        this.ColumnMap.Add(cm);
                    }
                }
            }

        }

        /// <summary>
        /// Constructor for the QueryParallelizer class.
        /// </summary>
        /// <param name="query">
        /// The query that will be called by the workers. The query should be formatted such that it contains
        /// a predicate (e.g. BETWEEN) that operates on an integer range (or some other data type converted 
        /// from an integer). The predicate should use placeholder variables, which are specified using the 
        /// minVariable and maxVariable parameters. Any given integer subrange should return a unique set of
        /// rows in order to ensure that the output of the entire operation is a unique set of rows.
        /// </param>
        /// <param name="minVariable">
        /// The name of the placeholder variable used for the minimum value in the query's integer range.
        /// </param>
        /// <param name="maxVariable">
        /// The name of the placeholder variable used for the maximum value in the query's integer range.
        /// </param>
        /// <param name="minValue">
        /// The minimum value in the entire integer range to be processed by the QueryParallelizer.
        /// </param>
        /// <param name="maxValue">
        /// The maximum value in the entire integer range to be processed by the QueryParallelizer.
        /// </param>
        /// <param name="numWorkerThreads">
        /// The number of workers that should be used to process the data in the integer range. Note that if 
        /// the range has fewer numbers than the number of workers specified here, or if the BatchSize property
        /// is set such that fewer sub-ranges will be produced than the number specified here, this value will
        /// be internally overridden in order to avoid creating more workers than are necssary.
        /// </param>
        /// <param name="rowLogic">
        /// The delegate to be used for row manipulation logic.
        /// </param>
        public QueryParallelizer(
            string query,
            string minVariable,
            string maxVariable,
            int minValue,
            int maxValue,
            int numWorkerThreads,
            RowLogicDelegate rowLogic)
        {
            if (numWorkerThreads < 1 || numWorkerThreads > 32)
                throw new ArgumentException("Number of worker threads must be between 1 and 32");

            long totalRange = (long)maxValue - (long)minValue + 1;
            if ((long)numWorkerThreads > totalRange)
                numWorkerThreads = (int)totalRange;

            if (minValue > maxValue)
                throw new ArgumentException("MinValue must be less than or equal to MaxValue.");

            this.query = query;
            this.minVariable = minVariable;
            this.maxVariable = maxVariable;
            this.minValue = minValue;
            this.maxValue = maxValue;
            this.numWorkerThreads = numWorkerThreads;
            this.rowLogic = rowLogic;

            targetConnectionString = ConnectionBuilder.LoopbackConnectionString;
        }

        /// <summary>
        /// This method is used to cause the QueryParallelizer to begin processing based on the values passed
        /// to the constructor and set via the public properties.
        /// </summary>
        /// <returns>
        /// The method returns an enumerator which streams back the output rows in the shape of the generic
        /// type used when the class was instantiated.
        /// </returns>
        public IEnumerable<T> Process()
        {
            if (isProcessing)
                throw new Exception("Processing can only be started a single time per instance");

            isProcessing = true;

            IntPtr callerIdentityToken = new IntPtr();
            if (impersonateCaller)
            {
                System.Security.Permissions.SecurityPermission secPerm =
                    new System.Security.Permissions.SecurityPermission(System.Security.Permissions.PermissionState.Unrestricted);
                secPerm.Assert();

                callerIdentityToken = SqlContext.WindowsIdentity.Token;
            }

            return (new internalEnumerator(
                query,
                minVariable,
                maxVariable,
                minValue,
                maxValue,
                numWorkerThreads,
                rowLogic,
                targetConnectionString,
                rowBufferSize,
                packageSize,
                batchSize,
                reuseConnection,
                bulkSettings,
                impersonateCaller,
                callerIdentityToken,
                additionalParameters));
        }

        private class itemPackage
        {
            public itemPackage(
                T[] itemList,
                int itemCount)
            {
                this.itemList = itemList;
                this.itemCount = itemCount;
            }

            public readonly T[] itemList;
            public readonly int itemCount;
        }

        private class threadMonitor
        {
            public threadMonitor(
                System.Threading.Thread t)
            {
                this.t = t;
            }

            private readonly System.Threading.Thread t;

            public bool IsThreadAlive
            {
                get
                {
                    return (t.IsAlive);
                }
            }
        }
    }
}
