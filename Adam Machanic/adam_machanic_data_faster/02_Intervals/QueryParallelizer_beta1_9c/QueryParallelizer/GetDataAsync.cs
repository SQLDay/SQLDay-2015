using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Threading;

namespace AdamMachanic.QueryTools
{
    /// <summary>
    /// This class allows the user to acquire data in a SQLCLR UDF without setting the DataAccess 
    /// property on the UDF attribute. This "hides" the data access from the query processor, thereby
    /// enabling a number of potentially better plan choices. Note that data access will be much slower
    /// when using this class than when accessing data directly. The idea is to use this class to help
    /// build a cache, not to use this class for general data access purposes.
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
    public class GetDataAsync
    {
        private readonly string query;
        private readonly string connectionString;
        private readonly BoundlessArray<object[]> data = new BoundlessArray<object[]>();

        private int rowCount = 0;
        private Exception ex;

        /// <summary>
        /// Additional parameters for the query. Making this public because these calls should be
        /// quick and the chance of someone being able to break things is minimal. I hope.
        /// </summary>
        public SqlParameter[] Parameters;

        public GetDataAsync(
            string query)
            : this(query, ConnectionBuilder.LoopbackConnectionString)
        {
        }

        public GetDataAsync(
            string query,
            string connectionString)
        {
            this.query = query;
            this.connectionString = connectionString;
        }

        //TODO: stream data through the roundRobinBuffer rather than returning the local array
        public IEnumerable<object[]> GetData()
        {
            Thread t = new Thread(new ThreadStart(this.asyncGet));
            t.Start();
            t.Join();

            if (this.ex != null)
                throw new Exception("Error retrieving data.", ex);

            for (int i = 0; i < this.rowCount; i++)
                yield return (this.data[i]);
        }

        private void asyncGet()
        {
            try
            {
                SqlClientPermission sqlPerm =
                    new SqlClientPermission(System.Security.Permissions.PermissionState.Unrestricted);
                sqlPerm.Assert();

                using (SqlConnection conn = new SqlConnection(connectionString))
                {
                    using (SqlCommand comm = conn.CreateCommand())
                    {
                        comm.CommandText = query;

                        if (this.Parameters != null)
                        {
                            foreach (SqlParameter p in this.Parameters)
                                comm.Parameters.Add(p);
                        }

                        conn.Open();

                        using (SqlDataReader reader = comm.ExecuteReader())
                        {
                            int count = reader.FieldCount;

                            while (reader.Read())
                            {
                                object[] o = new object[count];
                                reader.GetValues(o);
                                this.data[this.rowCount] = o;
                                this.rowCount++;
                            }
                        }
                    }
                }
            }
            catch (Exception e)
            {
                this.ex = e;
            }
        }
    }
}