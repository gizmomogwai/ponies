/++
 + License: MIT
 +/

module asciitable;

import std.string;

struct Row
{
    string[] columns;
    this(string[] data)
    {
        this.columns = data;
    }
}

struct AsciiTable
{
    ulong[] minimumWidths;
    Row[] rows;
    this(W...)(W minimumWidths)
    {
        this.minimumWidths = [minimumWidths];
    }

    AsciiTable add(V...)(V values)
    {
        if (values.length != minimumWidths.length)
        {
            throw new Exception("All rows must have length %s".format(minimumWidths.length));
        }
        rows ~= Row([values]);
        return this;
    }

    string toString(string linePrefix = "")
    {
        import std.algorithm;
        import std.string;

        foreach (row; rows)
        {
            foreach (idx, column; row.columns)
            {
                minimumWidths[idx] = max(minimumWidths[idx], column.length + 1);
            }
        }
        string res = "";
        foreach (row; rows)
        {
            if (res.length > 0)
            {
                res ~= "\n";
            }
            res ~= linePrefix;
            foreach (idx, column; row.columns)
            {
                res ~= leftJustify(column, minimumWidths[idx], ' ');
            }
        }
        return res;
    }
}

@("asciitable") unittest
{
    import unit_threaded;

    auto table = AsciiTable(10, 3, 5);
    table.add("1", "2", "3");
    table.add("4", "5", "6");
    table.toString.shouldEqual("1         2  3    \n" ~ "4         5  6    \n");
}
