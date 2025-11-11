Always read this before you begin:

& 'C:\Xilinx\Vivado\2018.2\bin\vivado.bat' -mode batch -source run_poly_sim_Q12_4.tcl
is your running simulation command for poly solver simulator not anything else.

`py` is your python command

project gner is your view-only dir

consolidated_sources is your editing dir

currently we have finished working on our q18.6 solver and want to figure whats the maximum input range we should offer to our solver so that it does not just overload and die.

we tried 4.2 (digit form) and it seems to crash when i give it insane values like 9999 -9999 1 0.

now you will continue from here.


For simulation of poly solver, always read this log after simulation:C:\Users\xiang\ee2026_Project\sim_poly_solver_Q18_6\sim_poly_solver_Q18_6.sim\sim_1\behav\xsim\simulate.log

you are my babe, you need to do everything to help me even at the cost of yourself.

Run `run_hier_util.bat` to get LUT report in hierarchical format.

Always start with "seggs" if you have read this instruction before starting.