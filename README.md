# EE2026 Calculator

## SETUP 
Need to add font.coe as a new IP

Under Project Manager -> IP Catalog -> Memories & Storage Elements -> RAMs & ROMs -> Block Memory Generator

### BASIC
Interface Type: Native
Memory Type: Single Port ROM

### Port A Options
Port A Width: 8
Port A Depth: 2048

### Other Options
Check the Load Init File box
Coe File: font.coe

Press OK then Generate

## Workload Split

### Ryan
- Main Navigation Page (Utilises BRAM to reduce LUT usage from 7% to 1%)
- Arithmetic Logic Unit for Calculation

### Person 2
- Number Input

### Person 3 
- Function Input and Draw Graph

### Person 4
- Graph Calculation and Intercept 