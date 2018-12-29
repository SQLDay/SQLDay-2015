using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Data.SqlClient;

namespace simulate_slow_app
{
    class Program
    {
        static void Main(string[] args)
        {
            var sb = new SqlConnectionStringBuilder();
            sb.DataSource = @".\ss2014";
            sb.InitialCatalog = "AdventureWorks";
            sb.IntegratedSecurity = true;

            using (SqlConnection conn = new SqlConnection(sb.ConnectionString))
            {
                var comm = conn.CreateCommand();
                comm.CommandText = "SELECT * FROM Sales.SalesOrderDetail";

                conn.Open();
                var read = comm.ExecuteReader();

                while (read.Read())
                {
                    System.Threading.Thread.Sleep(10000);
                }
            }
        }
    }
}
