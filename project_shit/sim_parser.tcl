# Vivado TCL Script - Run Parser Simulation

puts "=========================================="
puts "Starting Parser Simulation"
puts "=========================================="

# Open project
open_project C:/Users/xiang/ee2026_Project/project_shit/project_shit.xpr

# Add simulation sources
set sim_fileset [get_filesets sim_1]
set tb_file "C:/Users/xiang/ee2026_Project/project_shit/project_shit.srcs/sim_1/new/tb_parser_only.v"
if {[file exists $tb_file]} {
    add_files -fileset $sim_fileset -norecurse $tb_file -quiet
}

# Add parser source
set parser_file "C:/Users/xiang/ee2026_Project/project_vivado/features/parser/data_parser_accumulator.v"
if {[file exists $parser_file]} {
    add_files -norecurse $parser_file -quiet
}

# Update compile order
update_compile_order -fileset sources_1 -quiet
update_compile_order -fileset sim_1 -quiet

# Set top module
set_property top tb_parser_only [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]

puts "Launching simulation..."
launch_simulation -mode behavioral

puts "Running for 500ns..."
run 500ns

puts "=========================================="
puts "Simulation Complete"
puts "=========================================="

close_sim
exit
