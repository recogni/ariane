
package ariane_cfg_pkg;

    // ---------------
    // Global Config
    // ---------------
    // This is the new user config interface system. If you need to parameterize something
    // within Ariane add a field here and assign a default value to the config. Please make
    // sure to add a propper parameter check to the `check_cfg` function.
    localparam NrMaxRules = 16;

    typedef struct packed {
      int                               RASDepth;
      int                               BTBEntries;
      int                               BHTEntries;
      // PMAs
      int unsigned                      NrNonIdempotentRules;  // Number of non idempotent rules
      logic [NrMaxRules-1:0][63:0]      NonIdempotentAddrBase; // base which needs to match
      logic [NrMaxRules-1:0][63:0]      NonIdempotentLength;   // bit mask which bits to consider when matching the rule
      int unsigned                      NrExecuteRegionRules;  // Number of regions which have execute property
      logic [NrMaxRules-1:0][63:0]      ExecuteRegionAddrBase; // base which needs to match
      logic [NrMaxRules-1:0][63:0]      ExecuteRegionLength;   // bit mask which bits to consider when matching the rule
      int unsigned                      NrCachedRegionRules;   // Number of regions which have cached property
      logic [NrMaxRules-1:0][63:0]      CachedRegionAddrBase;  // base which needs to match
      logic [NrMaxRules-1:0][63:0]      CachedRegionLength;    // bit mask which bits to consider when matching the rule
      // cache config
      bit                               Axi64BitCompliant;     // set to 1 when using in conjunction with 64bit AXI bus adapter
      bit                               SwapEndianess;         // set to 1 to swap endianess inside L1.5 openpiton adapter
      //
      logic [63:0]                      DmBaseAddress;         // offset of the debug module
    } ariane_cfg_t;

    localparam ariane_cfg_t ArianeDefaultConfig = '{
      RASDepth: 2,
      BTBEntries: 32,
      BHTEntries: 128,
      // idempotent region
      NrNonIdempotentRules: 2,
      NonIdempotentAddrBase: {64'b0, 64'b0},
      NonIdempotentLength:   {64'b0, 64'b0},
      NrExecuteRegionRules: 3,
      //                      DRAM,          Boot ROM,   Debug Module
      ExecuteRegionAddrBase: {64'h8000_0000, 64'h1_0000, 64'h0},
      ExecuteRegionLength:   {64'h40000000,  64'h10000,  64'h1000},
      // cached region
      NrCachedRegionRules:    1,
      CachedRegionAddrBase:  {64'h8000_0000},
      CachedRegionLength:    {64'h40000000},
      //  cache config
      Axi64BitCompliant:      1'b1,
      SwapEndianess:          1'b0,
      // debug
      DmBaseAddress:          64'h0
    };

    // Function being called to check parameters
    function automatic void check_cfg (ariane_cfg_t Cfg);
      // pragma translate_off
      `ifndef VERILATOR
        assert(Cfg.RASDepth > 0);
        assert(2**$clog2(Cfg.BTBEntries)  == Cfg.BTBEntries);
        assert(2**$clog2(Cfg.BHTEntries)  == Cfg.BHTEntries);
        assert(Cfg.NrNonIdempotentRules <= NrMaxRules);
        assert(Cfg.NrExecuteRegionRules <= NrMaxRules);
        assert(Cfg.NrCachedRegionRules  <= NrMaxRules);
      `endif
      // pragma translate_on
    endfunction
    
    function automatic logic range_check(logic[63:0] base, logic[63:0] len, logic[63:0] address);
      // if len is a power of two, and base is properly aligned, this check could be simplified
      return (address >= base) && (address < (base+len));
    endfunction : range_check

    function automatic logic is_inside_nonidempotent_regions (ariane_cfg_t Cfg, logic[63:0] address);
      logic[NrMaxRules-1:0] pass;
      pass = '0;
      for (int unsigned k = 0; k < Cfg.NrNonIdempotentRules; k++) begin
        pass[k] = range_check(Cfg.NonIdempotentAddrBase[k], Cfg.NonIdempotentLength[k], address);
      end
      return |pass;
    endfunction : is_inside_nonidempotent_regions

    function automatic logic is_inside_execute_regions (ariane_cfg_t Cfg, logic[63:0] address);
      // if we don't specify any region we assume everything is accessible
      logic[NrMaxRules-1:0] pass;
      pass = '0;
      for (int unsigned k = 0; k < Cfg.NrExecuteRegionRules; k++) begin
        pass[k] = range_check(Cfg.ExecuteRegionAddrBase[k], Cfg.ExecuteRegionLength[k], address);
      end
      return |pass;
    endfunction : is_inside_execute_regions

    function automatic logic is_inside_cacheable_regions (ariane_cfg_t Cfg, logic[63:0] address);
      automatic logic[NrMaxRules-1:0] pass;
      pass = '0;
      for (int unsigned k = 0; k < Cfg.NrCachedRegionRules; k++) begin
        pass[k] = range_check(Cfg.CachedRegionAddrBase[k], Cfg.CachedRegionLength[k], address);
      end
      return |pass;
    endfunction : is_inside_cacheable_regions

endpackage