using System;
using System.Data.SqlClient;
using Microsoft.SqlServer.Server;
using System.Threading;

namespace AdamMachanic.QueryTools
{
    /// <summary>
    /// This class is designed to produce a loopback connection that points to the SQL Server instance and 
    /// specific database in which the QueryParallelizer resides.
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
    public static class ConnectionBuilder
    {
        private static readonly string connectionString;
        private static readonly Exception e;

        static ConnectionBuilder()
        {
            if (SqlContext.IsAvailable)
            {
                System.Security.Permissions.EnvironmentPermission envPerm =
                    new System.Security.Permissions.EnvironmentPermission(System.Security.Permissions.PermissionState.Unrestricted);
                envPerm.Assert();

                string instanceName = getInstanceName();
                if (instanceName == "MSSQLSERVER")
                    instanceName = null;

                System.Security.CodeAccessPermission.RevertAll();

                System.Security.Permissions.SecurityPermission secPerm =
                    new System.Security.Permissions.SecurityPermission(System.Security.Permissions.PermissionState.Unrestricted);
                secPerm.Assert();

                GetDbName g = new GetDbName(
                    instanceName,
                    new ManualResetEvent(false));

                System.Threading.Thread t = new Thread(new ThreadStart(g.DoIt));
                //t.Name = "QueryParallelizer: ConnectionBuilder Loopback Database Name";
                t.Start();
                g.m.WaitOne();

                if (null != g.E)
                    e = new Exception("Error in creating loopback connection", g.E);
                else
                    connectionString = g.sb.ConnectionString;
            }
            else
                connectionString = null;
        }

        private static string getInstanceName()
        {
            foreach (string arg in Environment.GetCommandLineArgs())
            {
                if (arg.Substring(0, 2) == "-s")
                    return (arg.Substring(2));
            }

            return ("MSSQLSERVER");
        }

        private class GetDbName
        {
            private readonly string instanceName;
            public readonly ManualResetEvent m;
            public readonly SqlConnectionStringBuilder sb;

            private Exception e;
            public Exception E
            {
                get
                {
                    return (this.e);
                }
            }

            public GetDbName(
                string instanceName,
                ManualResetEvent m)
            {
                this.instanceName = instanceName;
                this.m = m;

                this.sb = new SqlConnectionStringBuilder();

                //initial settings to grab the DB name -- these will be updated in DoIt
                this.sb.DataSource = "." + ((instanceName == null) ? "" : @"\" + instanceName);
                this.sb.IntegratedSecurity = true;
                this.sb.Pooling = false;
            }

            public void DoIt()
            {
                try
                {
                    using (SqlConnection conn = new SqlConnection(this.sb.ConnectionString))
                    {
                        System.Data.SqlClient.SqlClientPermission sqlPerm =
                            new SqlClientPermission(System.Security.Permissions.PermissionState.Unrestricted);
                        sqlPerm.Assert();

                        SqlCommand comm = conn.CreateCommand();
                        comm.CommandText =
                            "SELECT " +
                                "DB_NAME(a.db_id) " +
                            "FROM sys.dm_clr_appdomains AS a " +
                            "WHERE " +
                                "a.appdomain_name = @appdomain_name";
                        comm.Parameters.AddWithValue("@appdomain_name", AppDomain.CurrentDomain.FriendlyName);

                        conn.Open();

                        object o = comm.ExecuteScalar();
                        if (null == o)
                            throw new Exception("No DB name returned by loopback thread query");

                        //finish setting the connection string builder options
                        sb.InitialCatalog = (string)o;
                        sb.Pooling = true;
                        sb.Enlist = false;
                        sb.MaxPoolSize = 500;
                        sb.MinPoolSize = 100;
                        sb.ConnectTimeout = 45;
                    }
                }
                catch (Exception e)
                {
                    this.e = new Exception("Error getting database name", e);
                }
                finally
                {
                    m.Set();
                }
            }
        }

        /// <summary>
        /// When used inside of SQL Server, returns the loopback connection string. Otherwise returns a null
        /// instance of System.String.
        /// </summary>
        public static string LoopbackConnectionString
        {
            get
            {
                if (e != null)
                    throw new Exception("Error getting connection string", e);

                return (connectionString);
            }
        }
    }
}
