[Original sxi-spb bridge resource ulitization](https://docs.amd.com/r/en-US/pg073-axi-apb-bridge/Port-Descriptions)
[AMBA-APB protocol](https://www.youtube.com/watch?v=vPmHSmewOv4&start=2)

#### commands 
iverilog -o <compiled_file name> <directory1>/<file1> <directory2>/<file2>
vvp <compiled_file name>
gtkwave dump.vcd

iverilog -o top_module_check.vvp RTL/*.v TB?Top_module_tb.v
vvp top_module_check.vvp
gtkwave waves.vcd