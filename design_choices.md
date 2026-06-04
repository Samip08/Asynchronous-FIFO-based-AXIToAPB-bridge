### asynch_fifo_core
* gray coded pointers for synchronizing across read and write clk domains, using binary for local usage
* gray code pointers used only empty full logic
* Negedge rst prevent random power spikes in rst track to trigger rst
* rptr_gray_next, wptr_gray_next ensure the empty/full condition flips at correct clk cycle prevent overwrite/reading garbage value
* using rptr/wptr for empty/full logic allows wptr to go above 10(16 height) to 11 while rptr is at 00 essentially overwriting data
* rptr reads a data yet to be published from write side
![alt text](overwriting_wptr_full.png)
![alt text](reading_unpublished_rptr_empty.png)

* fixed using rptr_next, wptr_next(all of this is in gray code)
![alt text](working_async_fifo.png)