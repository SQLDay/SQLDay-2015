﻿using System;
using System.Data;
using System.Data.SqlClient;
using System.Data.SqlTypes;
using Microsoft.SqlServer.Server;


public partial class StoredProcedures
{
    [Microsoft.SqlServer.Server.SqlProcedure]
    public static void SpinFor20Seconds_Yield()
    {
        DateTime start = DateTime.Now;

        for (int j = 0; j < 320; j++)
        {
            //yield about every 1/16 of a second
            if (j > 0)
                System.Threading.Thread.Sleep(0);

            for (long i = 0; i < 13125000; i++)
            {
            }
        }
    }
};
