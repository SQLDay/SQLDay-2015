using System;
using System.Collections.Generic;
using System.Threading;

namespace AdamMachanic.QueryTools
{
    /// <summary>
    /// This class provides an alternative to List<> or Dictionary<int, V> and has been designed specifically 
    /// for use within SQLCLR environments. It is designed to store any amount of data without using any space on the 
    /// LOB heap. This greatly reduces GC overhead. However, it should be noted that this class may sacrifice performance 
    /// for the sake of its memory efficiency. It is generally slower than List<>, but the updated lock-free implementation
    /// in this version appears to be at least 2x faster than Dictionary<int, V>.
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
    /// (C) 2010-2013 Adam Machanic
    /// amachanic@gmail.com
    /// </summary>
    /// <typeparam name="T"></typeparam>
    public class BoundlessArray<T>
    {
        private const int SLOT_SIZE = 1291;
        private const int SLOT0_SIZE = 1666681;

        private volatile T[] slots1;
        private volatile T[][] slots2;
        private volatile T[][][] slots3;

        public BoundlessArray()
        {
            Clear();
        }

        public void Clear()
        {
            slots1 = null;
            slots2 = null;
            slots3 = null;
        }

        public T this[int key]
        {
            get
            {
                if (key < SLOT_SIZE)
                {
                    try
                    {
                        return (slots1[key]);
                    }
                    catch (NullReferenceException)
                    {
                        T[] slot0 = Interlocked.CompareExchange<T[]>(ref slots1, new T[SLOT_SIZE], null);

                        if (null == slot0)
                            slot0 = slots1;

                        return (slots1[key]);
                    }
                }
                else if (key < SLOT0_SIZE)
                {
                    int slot1Pos = key / SLOT_SIZE;
                    int slot2Pos = key % SLOT_SIZE;

                    try
                    {
                        return (slots2[slot1Pos][slot2Pos]);
                    }
                    catch (NullReferenceException)
                    {
                        T[][] slot0 = Interlocked.CompareExchange<T[][]>(ref slots2, new T[SLOT_SIZE][], null);

                        if (null == slot0)
                            slot0 = slots2;

                        T[] slot1 = Interlocked.CompareExchange<T[]>(ref slot0[slot1Pos], new T[SLOT_SIZE], null);

                        if (null == slot1)
                            return (slot0[slot1Pos][slot2Pos]);
                        else
                            return (slot1[slot2Pos]);
                    }
                }
                else
                {
                    int slot0Pos = key / SLOT0_SIZE;
                    key -= (slot0Pos * SLOT0_SIZE);
                    int slot1Pos = key / SLOT_SIZE;
                    int slot2Pos = key % SLOT_SIZE;

                    try
                    {
                        return (slots3[slot0Pos][slot1Pos][slot2Pos]);
                    }
                    catch (NullReferenceException)
                    {
                        T[][][] slot0 = Interlocked.CompareExchange<T[][][]>(ref slots3, new T[SLOT_SIZE][][], null);

                        if (null == slot0)
                            slot0 = slots3;

                        T[][] slot1 = Interlocked.CompareExchange<T[][]>(ref slot0[slot0Pos], new T[SLOT_SIZE][], null);

                        if (null == slot1)
                            slot1 = slot0[slot0Pos];

                        T[] slot2 = Interlocked.CompareExchange<T[]>(ref slot1[slot1Pos], new T[SLOT_SIZE], null);

                        if (null == slot2)
                            return (slot1[slot1Pos][slot2Pos]);
                        else
                            return (slot2[slot2Pos]);
                    }
                }
            }

            set
            {
                if (key < SLOT_SIZE)
                {
                    try
                    {
                        slots1[key] = value;
                    }
                    catch (NullReferenceException)
                    {
                        T[] slot0 = Interlocked.CompareExchange<T[]>(ref slots1, new T[SLOT_SIZE], null);

                        if (null == slot0)
                            slot0 = slots1;

                        slots1[key] = value;
                    }
                }
                else if (key < SLOT0_SIZE)
                {
                    int slot1Pos = key / SLOT_SIZE;
                    int slot2Pos = key % SLOT_SIZE;

                    try
                    {
                        slots2[slot1Pos][slot2Pos] = value;
                    }
                    catch (NullReferenceException)
                    {
                        T[][] slot0 = Interlocked.CompareExchange<T[][]>(ref slots2, new T[SLOT_SIZE][], null);

                        if (null == slot0)
                            slot0 = slots2;

                        T[] slot1 = Interlocked.CompareExchange<T[]>(ref slot0[slot1Pos], new T[SLOT_SIZE], null);

                        if (null == slot1)
                            slot0[slot1Pos][slot2Pos] = value;
                        else
                            slot1[slot2Pos] = value;
                    }
                }
                else
                {
                    int slot0Pos = key / SLOT0_SIZE;
                    key -= (slot0Pos * SLOT0_SIZE);
                    int slot1Pos = key / SLOT_SIZE;
                    int slot2Pos = key % SLOT_SIZE;

                    try
                    {
                        slots3[slot0Pos][slot1Pos][slot2Pos] = value;
                    }
                    catch (NullReferenceException)
                    {
                        T[][][] slot0 = Interlocked.CompareExchange<T[][][]>(ref slots3, new T[SLOT_SIZE][][], null);

                        if (null == slot0)
                            slot0 = slots3;

                        T[][] slot1 = Interlocked.CompareExchange<T[][]>(ref slot0[slot0Pos], new T[SLOT_SIZE][], null);

                        if (null == slot1)
                            slot1 = slot0[slot0Pos];

                        T[] slot2 = Interlocked.CompareExchange<T[]>(ref slot1[slot1Pos], new T[SLOT_SIZE], null);

                        if (null == slot2)
                            slot1[slot1Pos][slot2Pos] = value;
                        else
                            slot2[slot2Pos] = value;
                    }
                }
            }
        }

        public T Exchange(
            int key,
            T value)
        {
            if (key < SLOT_SIZE)
            {
                try
                {
                    T priorValue = slots1[key];
                    slots1[key] = value;

                    return (priorValue);
                }
                catch (NullReferenceException)
                {
                    T[] slot0 = Interlocked.CompareExchange<T[]>(ref slots1, new T[SLOT_SIZE], null);

                    if (null == slot0)
                        slot0 = slots1;

                    T priorValue = slots1[key];
                    slots1[key] = value;

                    return (priorValue);
                }
            }
            else if (key < SLOT0_SIZE)
            {
                int slot1Pos = key / SLOT_SIZE;
                int slot2Pos = key % SLOT_SIZE;

                try
                {
                    T priorValue = slots2[slot1Pos][slot2Pos];
                    slots2[slot1Pos][slot2Pos] = value;

                    return (priorValue);
                }
                catch (NullReferenceException)
                {
                    T[][] slot0 = Interlocked.CompareExchange<T[][]>(ref slots2, new T[SLOT_SIZE][], null);

                    if (null == slot0)
                        slot0 = slots2;

                    T[] slot1 = Interlocked.CompareExchange<T[]>(ref slot0[slot1Pos], new T[SLOT_SIZE], null);

                    if (null == slot1)
                    {
                        T priorValue = slot0[slot1Pos][slot2Pos];
                        slot0[slot1Pos][slot2Pos] = value;

                        return (priorValue);
                    }
                    else
                    {
                        T priorValue = slot1[slot2Pos];
                        slot1[slot2Pos] = value;

                        return (priorValue);
                    }
                }
            }
            else
            {
                int slot0Pos = key / SLOT0_SIZE;
                key -= (slot0Pos * SLOT0_SIZE);
                int slot1Pos = key / SLOT_SIZE;
                int slot2Pos = key % SLOT_SIZE;

                try
                {
                    T priorValue = slots3[slot0Pos][slot1Pos][slot2Pos];
                    slots3[slot0Pos][slot1Pos][slot2Pos] = value;

                    return (priorValue);
                }
                catch (NullReferenceException)
                {
                    T[][][] slot0 = Interlocked.CompareExchange<T[][][]>(ref slots3, new T[SLOT_SIZE][][], null);

                    if (null == slot0)
                        slot0 = slots3;

                    T[][] slot1 = Interlocked.CompareExchange<T[][]>(ref slot0[slot0Pos], new T[SLOT_SIZE][], null);

                    if (null == slot1)
                        slot1 = slot0[slot0Pos];

                    T[] slot2 = Interlocked.CompareExchange<T[]>(ref slot1[slot1Pos], new T[SLOT_SIZE], null);

                    if (null == slot2)
                    {
                        T priorValue = slot1[slot1Pos][slot2Pos];
                        slot1[slot1Pos][slot2Pos] = value;

                        return (priorValue);
                    }
                    else
                    {
                        T priorValue = slot2[slot2Pos];
                        slot2[slot2Pos] = value;

                        return (priorValue);
                    }
                }
            }
        }
    }
}