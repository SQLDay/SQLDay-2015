using System;
using System.Collections.Generic;
using System.Collections.Concurrent;
using System.Data.SqlClient;

namespace intervals
{
    public class IntervalCounter
    {
        private SortedList<DateTime, int> endDates = new SortedList<DateTime, int>();
        private DateTime currentStartDate = new DateTime(1900, 01, 01);
        private int currentOnCount = 0;
        //Removing from the endDates collection is expensive; instead of removing, just ignore dates we're done with
        private int minEndOrdinal = 0;
        private Result currentResult = new Result();
        private Queue<Result> results = new Queue<Result>();

        public void Init()
        {
            endDates.Clear();
            currentStartDate = new DateTime(1900, 01, 01);
            currentOnCount = 0;
            minEndOrdinal = 0;
            currentResult = new Result();
        }

        public void Accumulate(
            DateTime start,
            DateTime end)
        {
            //Verify that the dates are being passed in the correct order
            if (start < currentStartDate)
                throw new ArgumentException(String.Format("start date passed to accumulate ({0}) was less than prior start date ({1})", start, currentStartDate));

            if (start > currentStartDate)
            {
                //any end dates that need to be dealt with?
                while (
                    currentOnCount > 0 &&
                    endDates.Keys[minEndOrdinal] <= start)
                {
                    updateAndSend();
                }

                if (start > currentStartDate)
                {
                    if (currentOnCount > 0)
                    {
                        //return an interval between current start date and start - 1
                        sendResult(start.AddDays(-1));
                    }

                    //set current start date to start
                    currentStartDate = start;
                }
            }

            if (!endDates.ContainsKey(end))
                endDates.Add(end, 1);
            else
                endDates[end] += 1;

            currentOnCount++;
        }

        public IEnumerable<Result> Terminate()
        {          
            //Anything left not already enqueued?
            while (currentOnCount > 0)
                updateAndSend();

            while (results.Count > 0)
                yield return (results.Dequeue());

            //send the final row
            if (currentResult.Count > 0)
                yield return (currentResult);
        }

        private void updateAndSend()
        {
            DateTime minEndDate = endDates.Keys[minEndOrdinal];

            //return an interval between current start date and end date
            sendResult(minEndDate);

            //set current start date to end date + 1
            currentStartDate = minEndDate;

            //decrement current on count by however many times we've seen this end date
            currentOnCount -= endDates.Values[minEndOrdinal];

            //ignore the min end date for further passes
            minEndOrdinal++;
        }

        private void sendResult(DateTime end)
        {
            if (currentResult.Count > 0)
            {
                if (
                    //ignore gaps of 1 day
                    currentStartDate == currentResult.End.AddDays(1) &&
                    currentOnCount == currentResult.Count)
                {
                    currentResult.End = end.AddDays(-1);
                }
                else
                {
                    results.Enqueue(currentResult);

                    currentResult = new Result() { Start = currentStartDate, End = end.AddDays(-1), Count = currentOnCount };
                }
            }
            else
            {
                currentResult.Start = currentStartDate;
                currentResult.End = end.AddDays(-1);
                currentResult.Count = currentOnCount;
            }
        }

        public class Result
        {
            public DateTime Start;
            public DateTime End;
            public int Count;
        }
    }
}
