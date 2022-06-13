## Kernel sees the issue!
    - https://lkml.org/lkml/2022/6/6/980
    
    
## Stosb Bandwidth doesn't scale well

It gets better with multiple threads [(at least on my TGL Laptop)](https://docs.google.com/spreadsheets/d/1f6N9EVqHg71cDIR-RALLR76F_ovW5gzwIWr26yLCmS0/edit?usp=sharing)

- Appears to be because it never switches to non-cachable writes so it
  spending extra bandwidth getting data back from RFOs
  
  

