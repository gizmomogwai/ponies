/++
 + License: MIT
 +/

module asciitable;

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
    int[] widths;
    Row[] rows;
    this(W...)(W widths)
    {
        this.widths = [widths];
    }

    AsciiTable add(V...)(V values)
    {
        rows ~= Row([values]);
        return this;
    }

    string toString(string linePrefix = "")
    {
        import std.string;

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
                res ~= leftJustify(column, widths[idx], ' ');
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
