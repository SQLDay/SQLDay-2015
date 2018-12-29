using System;
using System.Collections.Generic;
using System.Data;

namespace AdamMachanic.QueryTools
{
    /// <summary>
    /// This class is designed to help with conversions between the SqlDbType enumeration and .NET types.
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
    public sealed class TypeConverter
    {
        private static readonly Dictionary<SqlDbType, Type> types;

        static TypeConverter()
        {
            types = new Dictionary<SqlDbType, Type>();
            types.Add(SqlDbType.BigInt, typeof(Int64));
            types.Add(SqlDbType.Binary, typeof(byte[]));
            types.Add(SqlDbType.Bit, typeof(bool));
            types.Add(SqlDbType.Char, typeof(string));
            types.Add(SqlDbType.Date, typeof(DateTime));
            types.Add(SqlDbType.DateTime, typeof(DateTime));
            types.Add(SqlDbType.DateTime2, typeof(DateTime));
            types.Add(SqlDbType.DateTimeOffset, typeof(DateTime));
            types.Add(SqlDbType.Decimal, typeof(decimal));
            types.Add(SqlDbType.Float, typeof(double));
            types.Add(SqlDbType.Image, typeof(byte[]));
            types.Add(SqlDbType.Int, typeof(Int32));
            types.Add(SqlDbType.Money, typeof(decimal));
            types.Add(SqlDbType.NChar, typeof(string));
            types.Add(SqlDbType.NText, typeof(string));
            types.Add(SqlDbType.NVarChar, typeof(string));
            types.Add(SqlDbType.Real, typeof(double));
            types.Add(SqlDbType.SmallDateTime, typeof(DateTime));
            types.Add(SqlDbType.SmallInt, typeof(Int16));
            types.Add(SqlDbType.SmallMoney, typeof(decimal));
            types.Add(SqlDbType.Text, typeof(string));
            types.Add(SqlDbType.Time, typeof(DateTime));
            types.Add(SqlDbType.Timestamp, typeof(byte[]));
            types.Add(SqlDbType.TinyInt, typeof(byte));
            types.Add(SqlDbType.UniqueIdentifier, typeof(Guid));
            types.Add(SqlDbType.VarBinary, typeof(byte[]));
            types.Add(SqlDbType.VarChar, typeof(string));
        }

        /// <summary>
        /// This method returns the appropriate .NET type to which data can be converted, based on the data's
        /// SqlDbType.
        /// </summary>
        /// <param name="type">
        /// The SqlDbType to be converted.
        /// </param>
        /// <returns>
        /// The System.Type that corresponds to the SqlDbType.
        /// </returns>
        public static Type ConvertToNetType(SqlDbType type)
        {
            return (types[type]);
        }
    }
}
