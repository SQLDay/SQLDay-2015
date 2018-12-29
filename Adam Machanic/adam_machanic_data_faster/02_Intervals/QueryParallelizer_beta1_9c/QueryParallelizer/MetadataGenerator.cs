using System;
using System.Collections.Generic;
using Microsoft.SqlServer.Server;
using System.Data.SqlClient;
using System.Data;

namespace AdamMachanic.QueryTools
{
    /// <summary>
    /// This class is designed to help acquire metadata about the result shape of a given query. It can be used
    /// in cases where a dynamic query is passed into the QueryParallelizer and the shape is needed in order to
    /// output rows.
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
    public static class MetadataGenerator
    {
        /// <summary>
        /// This method gets the metadata about the result shape of the input query.
        /// </summary>
        /// <param name="query">
        /// The query for which to return shape information.
        /// </param>
        /// <param name="minVar">
        /// The variable name used in the query to denote the minimum end of an integer range.
        /// </param>
        /// <param name="maxVar">
        /// The variable name used in the query to denote the maximum end of an integer range.
        /// </param>
        /// <returns>
        /// A collection of SqlMetaData objects, corresponding to each column returned by the query.
        /// </returns>
        public static SqlMetaData[] GetQueryMetadata(
            string query,
            string minVar,
            string maxVar)
        {
            return GetQueryMetadata(query, minVar, maxVar, null);
        }

        /// <summary>
        /// This method gets the metadata about the result shape of the input query.
        /// </summary>
        /// <param name="query">
        /// The query for which to return shape information.
        /// </param>
        /// <param name="minVar">
        /// The variable name used in the query to denote the minimum end of an integer range.
        /// </param>
        /// <param name="maxVar">
        /// The variable name used in the query to denote the maximum end of an integer range.
        /// </param>
        /// <param name="targetConnectionString">
        /// Used to override the connection on which the query is tested. If not used, the loopback connection
        /// will be used.
        /// </param>
        /// <returns>
        /// A collection of SqlMetaData objects, corresponding to each column returned by the query.
        /// </returns>
        public static SqlMetaData[] GetQueryMetadata(
            string query, 
            string minVar, 
            string maxVar,
            string targetConnectionString)
        {
            SqlClientPermission sqlPerm = new SqlClientPermission(System.Security.Permissions.PermissionState.Unrestricted);
            sqlPerm.Assert();

            DataTable dt = null;

            using (SqlConnection conn = new SqlConnection((targetConnectionString == null) ? ConnectionBuilder.LoopbackConnectionString : targetConnectionString))
            {
                using (SqlCommand comm = conn.CreateCommand())
                {
                    comm.CommandText = "SET FMTONLY ON;";
                    conn.Open();
                    comm.ExecuteNonQuery();

                    comm.CommandText = query;
                    comm.Parameters.Add(minVar, SqlDbType.Int).Value = int.MinValue;
                    comm.Parameters.Add(maxVar, SqlDbType.Int).Value = int.MaxValue;
                    using (SqlDataReader r = comm.ExecuteReader())
                    {
                        dt = r.GetSchemaTable();
                        if (dt == null)
                        {
                            throw new Exception("Metadata Generator found no columns in the input query");
                        }
                    }
                }
            }

            SqlMetaData[] cols = new SqlMetaData[dt.Rows.Count];

            for (int i = 0; i < dt.Rows.Count; i++)
            {
                //Different SqlMetaData overloads are required
                //depending on the data type of the column
                switch ((SqlDbType)(dt.Rows[i]["ProviderType"]))
                {
                    case SqlDbType.Decimal:
                        cols[i] = 
                            new SqlMetaData(
                                (string)(dt.Rows[i]["ColumnName"]),
                                (SqlDbType)(dt.Rows[i]["ProviderType"]),
                                (byte)(Int16)(dt.Rows[i]["NumericPrecision"]),
                                (byte)(Int16)(dt.Rows[i]["NumericScale"]));
                        break;
                    case SqlDbType.Binary:
                    case SqlDbType.Char:
                    case SqlDbType.NChar:
                    case SqlDbType.NVarChar:
                    case SqlDbType.VarBinary:
                    case SqlDbType.VarChar:
                        cols[i] =
                            new SqlMetaData(
                                (string)(dt.Rows[i]["ColumnName"]),
                                (SqlDbType)(dt.Rows[i]["ProviderType"]),
                                ((long)((int)(dt.Rows[i]["ColumnSize"])) == 2147483647) ? (long)-1 : (long)((int)(dt.Rows[i]["ColumnSize"])));
                        break;
                    default:
                        cols[i] =
                            new SqlMetaData(
                                (string)(dt.Rows[i]["ColumnName"]),
                                (SqlDbType)(dt.Rows[i]["ProviderType"]));
                        break;
                }
            }

            return (cols);
        }
    }
}
