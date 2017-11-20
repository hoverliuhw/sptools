#!/usr/bin/perl 
# generate breakpoint file
# based: tliu002 2009/04/25 16:45:18 <Tao.Liu@alcatel-lucent.com>
# enhanced: xiangdzh 2012/03/29 <Xiangdong.Zhou@alcatel-lucent.com>

# import
use File::Spec;
use File::Basename;
use Cwd;
# use strict 'vars';

#showing the progress, 10,000 lines incr one grid
use constant MAX_Grid   => 50;    # i think the lines number < 130w lines
use constant Const_Grid => 50;
our $cur_pro_num = 0;
our $OneGrid = Const_Grid / MAX_Grid;

# hash table definition
our %config = (
	"level"		=> 1,
	"file"		=> "spa.bp"
);
our %scope = (
	"fsm"			=> "default",
	"state"			=> "default",
	"event"			=> "default",
	"def_function"	=> "default"
);
our %mark = (
	"table"		=> "===>",
	"function"	=> "===>function:",
	"return"	=> "===>"
);
our %skip = (
	"default default Svr_Set_Subtrace" => 1,
	"default default Debug_Info_Func" => 1,
	"default default Set_Call_Dynamic_Flag" => 1,
	"default default Get_Call_Dynamic_Flag" => 1,
	"default default Set_Call_Dynamic_String" => 1,
	"default default Get_Call_Dynamic_String" => 1,
	"default default Set_Call_Dynamic_Counter" => 1,
	"default default Get_Call_Dynamic_Counter" => 1,
	"default default Set_Call_Dynamic_Long_Counter" => 1,
	"default default Get_Call_Dynamic_Long_Counter" => 1,
	"default default Set_Call_Dynamic_Float" => 1,
	"default default Get_Call_Dynamic_Float" => 1
);

our %GlobalVarValue = (
	"Glb_DEBUG_LEVEL" => 9,
	"Glb_Cache_Table_Clear_Interval" => 3600,
	"Glb_Service_Measurement_Interval" => 3600
);
our %GlobalVarTitle = (
	"Glb_Cache_Table_Clear_Interval" => "Do you want generate following BP to disable Cache_Table_Clear?",
	"Glb_Service_Measurement_Interval" => "Do you want generate following BP to disable flood service measurement log?"
);
our %GlobalVarOpen = (
	"Glb_DEBUG_LEVEL" => 1,
	"Glb_Cache_Table_Clear_Interval" => 0,
	"Glb_Service_Measurement_Interval" => 0
);
our @GlobalVar = ("Glb_DEBUG_LEVEL", "Glb_Service_Measurement_Interval", "Glb_Cache_Table_Clear_Interval");

our @ALL_BP = ();
our @CodePoint = (1);
our $func_name = "";
our %args = @ARGV;
our $Inputfile = "";
our $MYNODE    = $ENV{MYNODE};
our $Is_EPAY = 0;
our $BP_LVL = 0;
our $BP_Level = 0;
our $BP_F = "";
our $BP_File = "";

# Regex
our $Match_2Brack_PATTERN = '\(((\([^\(\)]*\)|[^\(\)]*)*)\)';
our $Function_TYPE_PATTERN = '(def_function)\s*([a-zA-Z0-9_!]*)\s*'.$Match_2Brack_PATTERN;
our $Match_1Brack_PATTERN = '\(([^\(\)]*)\)';
our $Table_TYPE_PATTERN = '(element_exists|best_match|prefix_matches)\s*'.$Match_1Brack_PATTERN;
our $IgnoreFunction =
	'get_spa_process_status|clock|LDAP_Check_Account_Expiration|printable_hex_to_raw_string|counter|power|ftoi|element_exists';
our $IgnoreSLLFunction = 
	'Get_Day_ID|UnixTime_To_Date_TimeZone|Calculate_End_Date|Insert_Annc|map|Calculate_First_Day_Current_Period|Get_Call_Dynamic_Counter|Get_Call_Dynamic_Flag|Get_Call_Dynamic_String|Get_Call_Dynamic_Long_Counter|Get_Call_Dynamic_Float|Convert_Value_To_Text_String|Get_Total_Reserved_Bucket|Get_Total_Captured_Bucket|Get_Total_Refunded_Bucket|Parser_URL_Format|Diam_COSP_Exists_In_ExtCOSP|Need_Determine_Zone|Date_Format_Conversion|Fill_Text_Format|Get_Long_Length_Value_From_EPM';
our $ignoreTable =
	'Local_Reset_Discount_Info_tbl|L_Diam_BOU_Index_tbl|L_SPI_UC_Cross_tbl|L_SPI_Ro_Info_tbl';

# common function
sub usage {
	my $pstr = <<EOF
Usage:	genbpN [-f src_file] [-l bp_level] [-o bpfile]
	genbpN [-spa spa_name] [-l bp_level] [-o bpfile]
	genbpN [-h]	look for this help
	
	parameters:
	src_file	target spa source file name, eg. EPAY274.src
	spa_name	target spa name, eg. EPAY274
	bp_level	1~3, different details in breakpoints, Default Value: 1
			1) only generate table search, eg. element_exists, prefix_matches, best_match
			2) including (1), more generate function invoke bp, eg. def_function, subrouting
			3) including (2), more generate function return bp, eg. return
			*) more then 3, will be think as 3, less then 1 will be think as 1
	bpfile		bp file name will be generated, if not provisioned, bpfile name will be "spa.bp"
EOF
      ;
    print $pstr;
    exit 0;
}

sub p_error {
    print @_;
    usage;
}

sub incr_progress {
	my ($process) = @_;
    #$progress->update( $cur_pro_num++ ) if $cur_pro_num <= MAX_Grid;
    $cur_pro_num ++;
    $cur_pro_num = MAX_Grid		if ($process == 100);

    my $t_t = int( $cur_pro_num * $OneGrid );
    $t_t = Const_Grid 			if $t_t > Const_Grid;

    print "\r", 'Parsed: [', '=' x $t_t, ( " " x ( Const_Grid - $t_t ) ), '] ';
    printf( "%.0f %", $t_t / Const_Grid * 100 );
}

FILE;
OUTPUT;
sub openFile {
	my ($file, $bp) = @_;

	unless(open(FILE, "$file")) {
		print "can not open $file";
		return -1;
	}
	
	unless(open(OUTPUT, $bp)) {
		print "can not open $bp";
		return -1;
	}
	
	return 0;
}

sub closeFile {
	print OUTPUT "detach\n"; #quit the debug mode
	close(FILE);
	close(OUTPUT);
}

sub comments {
	my ($line) = @_;

	if ($line =~ /^\s*(#.*)?$/o) {
		return 1;
	} else {
		return 0;
	}
}

sub escape {
	my $line = "";	
	while (<FILE>) {
		#checkLineNo();
		$line = $_;
		if ($line =~ /^\s*%\}/o) {
			return 0;
		}
	}

	return -1;
}

sub dynamic {
	my $line = "";
	while (<FILE>) {
		#checkLineNo();
		$line = $_;
		if ($line =~ /^\s*end\s+dynamic/o) {
			return 0;
		}
	}

	return -1;
}

sub subroutine {
	my ($name, $str) = @_;
	my $line = "";
	my $linenum = 0;

	while(<FILE>) {
		#checkLineNo();
		$line = $_;
		if ($line =~ /^\s*end\s+subroutine/o) {
			return 0;
		}
	}
	
	return 0;
}

sub generateLineBp {
	
}

sub generateBp {
	my ($linenum, $context) = @_;
	
	my $pr_str = "at $linenum \nprint(\n$context\n) \nend at \n";
	push(@ALL_BP, $pr_str);
}

sub process_table_search {
    my ( $type, $params ) = @_;

    if ( $type =~ m/element_exists|best_match|prefix_matches/o ) {
        my @params_tmp = split( /,/, $params );

        if ( @params_tmp + 0 >= 2 ) {
            my $tb_name = $params_tmp[0];
            my $tb_indx = $params_tmp[1];

            #2011/08/18 fix, skip ignor table
        	return '' if $tb_indx =~ m/^\s*($ignoreTable)\./o;
           	    
            #2010/10/19 22:49:01 fix, skip element_exist with table.index as key
            return '' if $tb_indx =~ /\.index$/o;
            
            return '"' .$mark{"table"}." $tb_name" . ' key=",' . $tb_indx;
        }
    }
    return '';
}

sub process_function {
    my ($type, $name, $params) = @_;
    my $func_name = $name;
	my $tmp = "";
	my $tmp1 = "";
	my $idx = 0;

    trim_string($params);
    if ( $type =~ m/def_function/o ) {
		my @params_arr = split( /,/, $params );

		my @params_arr_tmp = ();
        for ( $idx = 0 ; $idx <= $#params_arr ; $idx++ ) {
            $params_arr[$idx] =~ /^\s*([a-zA-Z0-9_!]*)(.*)$/o;
            my $tmp_param = $1;
            $tmp_param .= '[]' if ( $2 =~ /table/oi );
            push( @params_arr_tmp, $tmp_param );
        }
        @params_arr = @params_arr_tmp;

        $tmp1 = "(\",\n";
        if ( $#params_arr >= 0 ) {
            for ( $idx = 0 ; $idx < $#params_arr ; $idx++ ) {
                $tmp1 =
                  "$tmp1\"$params_arr[$idx]=\",$params_arr[$idx],\",\",\n";
            }
            $tmp1 = "$tmp1\"$params_arr[$idx]=\",$params_arr[$idx],\n";
        }
        $tmp1 = "$tmp1\")\"";
        $tmp  = "\"".$mark{"function"}." $func_name $tmp1";
        
        #Member_List is not a table, skip.
        return '' if $tmp =~ m/Member_List\[\]/o;
        return $tmp;
    }
    return '';
}

sub process_function_return {
    my ( $type, $params, $fun_name ) = @_;
    
    if ($BP_LVL >=3 && $type =~ /return/o ) {
        #special for SLL invoke function
        #return "\"".$mark{"return"}." $fun_name return: !shit,BP un-available here!\""
        return "\"".$mark{"return"}." $func_name return: BP un-available here!\""
            if $params =~ /$IgnoreSLLFunction/o;
        trim_string($params);
		#print $params."\n";
        $params =~ s/^\s*\((.*)\)/\1/g;

        #return '' if $params =~ /\(/o;

        #special for invoke builtin function
        #Note: for current, can not add built-in function into breakpoint, so ignore it
        #
        $params = '"BP_LIMIT: ' . $1 . '"'
          if ($params =~ /($IgnoreFunction)\s*\(/o);
        my $ret_res = $params;
        
        #skip return with a expression
        return ''	if ($params =~ m/\/+/o);
        return "\"".$mark{'return'}." ".$func_name." return: \",$ret_res";
    }
    return '';
}

# conj many lines without '\n' and '#.*'
sub trim_string {
    my $str = \shift;
    if ( $$str =~ /^\s*#/o ) {
        $$str = '';
        return 1;
    }
    $$str =~ tr/\n//d;

    #$$str =~ s/^\s*|\s*$|[^"#]#+.*$//go;
    $$str =~ s/^\s*//go;
    $$str =~ s/([^"#])#+.*$/\1/go;

    return 1;
}

# is need more line
sub need_more_line {
    my ($in_str, $type ) = @_;
    my $num = 1;
    my $idx = index( $in_str, '(', 0 );

    return 0 if ( $idx < 0 );

    $idx += 1;
    my @tmp = split( //, $in_str );
    while ( $idx < length($in_str) && $num != 0 ) {
        if ( $tmp[$idx] eq '(' ) {
            $num++;
        }
        elsif ( $tmp[$idx] eq ')' ) {
            $num--;
        }
        $idx++;
    }
    if ( $num > 0 ) {
        return 1;
    }
    elsif ( $num == 0 ) {
        my $tmp_str = substr( $in_str, $idx );
        return 1 if $tmp_str =~ /^\s*$/o && $type == 1;
        return 0;
    }
    return 0;
}

sub Is_Brace_Match_B {
    my ($str) = @_;
	my $len = 0;

	while(1) {
		if ($str =~ /\(/o) {
			$str =~ s/\(//;
			$len ++;
		} elsif ($str =~ /\)/o) {
			$str =~ s/\)//;
			$len --;
		} else {
			last;
		}
	}
	
	if ($len == 0) {
		return 1;
	} else {
		return 0;
	}
}

sub Is_Brace_Match {
    my ($str) = @_;
    my $pos1 = 0;
    my $pos2 = length($str) - 1;
    while (1) {
        my $idx = index( $str, '(', $pos1 );
        my $ridx = rindex( $str, ')', $pos2 );
        if ( $idx >= 0 && $ridx >= 0 ) {
            $pos1 = $idx + 1;
            $pos2 = $ridx - 1;
        }
        elsif ( $idx < 0 && $ridx < 0 ) {
            return 1;
        }
        else {
            return 0;
        }
    }
}

#print Is_Brace_Match("return (substring(Input_String,1,2):")."\n";
#print Is_Brace_Match("return (substring(Input_String,1,2):substring(Input_String,4,2):")."\n";
#print Is_Brace_Match("return (substring(Input_String,1,2):substring(Input_String,4,2):substring(Input_String,7,2))")."\n";
#exit 0;

sub def_function {
	my ($name, $line) = @_;
	my $pr_str = "";
	my $execline = "";
	my $linenum = 0;
	my $fun_name = "";
	my $new_line = "";

	$func_name = $name;
	# check the function whether be skipped	
	if ($BP_LVL >= 2) {
		trim_string($line);
		
		#bug fix, def_function has no parameter and parens
		if ($line =~ /^\s*def_function\s*[\w!]+\s+[\w!]+/o) {
			$line =~ s/^(\s*def_function\s*[\w!]+\s*)/\1\(\)/g;
		}

        #for def_function, look for the first '('
        while ( $line !~ /\(/o ) {
        	#print "$new_line\n";
        	#checkLineNo();
            $new_line = <FILE>;
            trim_string($new_line);
            $line .= $new_line;
        }
		
		#get One Whole Line for function defination
		while ((need_more_line($line, 1) == 1) && ($new_line = <FILE>)) {
			#print $line."\n";
			#checkLineNo();
		    trim_string($new_line);
		    $line .= $new_line;
		}

		#print $line."\n";
		$line =~ m/$Function_TYPE_PATTERN/o;
		$fun_name = $2;
		my $param = $3;
		$pr_str = process_function($1, $2, $3);
		if ($pr_str eq '') {
			#my $linenum = $.;
			#print "[".$linenum."]get $fun_name parameters failed($param).\n";
			#exit 0;
			return -1;
		}
		
		# fetch the first executable line
		$execline = fetchFisrtExecLine ($line);
		$linenum = $.;
		generateBp($linenum, $pr_str);

		#2010/06/12 10:05:58 fix: if the 1st line is return, need generate function return bp for this line
		if( $BP_LVL >= 3 && $execline =~ /^\s*return(.*)$/o){
			parse_statement_return($1);
		}
	}
}

sub fetchFisrtExecLine {
	my ($line) = @_;
	my $new_line = "";
	
	if ( $line =~ /\s*dynamic\s*/o ) {
        while ( $new_line = <FILE> ) {
        	#checkLineNo();
            next if ( $new_line =~ /^\s*#|^\s*$/o );
            last if ( $new_line =~ /\s*end\s*dynamic/o );
        }

        while ( $new_line = <FILE> ) {
    	   	#checkLineNo();
    	   	last if ( $new_line !~ /^\s*#|^\s*$/o );
    	}

    } else {
        #look for the first executable line in function
        while ( $new_line = <FILE> ) {
        	#checkLineNo();
            last if ( $new_line !~ /^\s*#|^\s*$/o );
        }
        if ( $new_line =~ /^\s*dynamic/o ) {
            while ( $new_line = <FILE> ) {
            	#checkLineNo();
                next if ( $new_line =~ /^\s*#|^\s*$/o );
                last if ( $new_line =~ /\s*end\s*dynamic/o );
            }
            while ( $new_line = <FILE> ) {
    	    	#checkLineNo();
    	    	last if ( $new_line !~ /^\s*#|^\s*$/o );
    		}
        }
    }
    
    return $new_line;
}

# parsing
sub parsing {
	my $line = "";
	my $linenum = 0;
	my $prt_str = "";
	my $tmp = 0;

	$| = 1;
	incr_progress(1);
	dynamic();
	while (<FILE>) {
		$line = $_;
		#checkLineNo();
		next		if (comments($line) == 1);

	    if ( $line =~ /^\s*escape\s*/o ) {
	    	escape();
	    	next;
	    }
	    #$tmp ++;
	    #if ( $tmp > 50000 ) {
	    #    $tmp = 0;
	    #    incr_progress(1);
	    #}

		if ($line =~ /^\s*subroutine\s+([\w!]+)/o) {
			subroutine($1, $line);
			next;
		}

		if ($line =~ /^\s*(if|test|elif|while)[^\w_]/o) {
			# generate bp for table when met element_exist in switch
			parse_conditon_table($1, $line);

		} elsif ($line =~ /^\s*set\s+Glb_Best_Match\s*=/o) {
			# generate bp for table when met best_match in set
			parse_statement_table($line);

		} elsif ($line =~ /^\s*return(.*)$/o) {
			# generate bp for table when met best_match in set
			parse_statement_return($1);

		} elsif ($line =~ /^\s*(def_function|event|state|fsm)\s+([\w!]+)/o) {
			# set scope
			my $type = $1;
			my $name = $2;
			setScope($type, $name);
			def_function($name, $line)		if ($type eq "def_function");

		} elsif ($line =~ /^\s*end\s+(def_function|event|state|fsm)\b/o) {
			# reset scope
			resetScope($1);
		}
	}

	incr_progress(100);
	#print "well done.\n";
}

sub parse_conditon_table {
	my ($key, $line) = @_;
	my $one_line_if_then = 0;
	my $new_line = "";
	my $linenum = $.;
	my $IsFromElsIf = 0;

	trim_string($line);
	$one_line_if_then = 1 if $line =~ /\s+then/o;
	#get One Whole Line of if
	while ( ( $one_line_if_then == 0 ) && ( $new_line = <FILE> ) ) {
		#checkLineNo();
	    next if ( $new_line =~ /^\s*#|^\s*$/o );
	    last if ( $new_line =~ /^\s*(then|case|exit|do)/o );
	    trim_string($new_line);
	    $line = $line . $new_line;
	    $one_line_if_then = 1		if $line =~ /\s+then/o;
	}

	#bugfix:for elif, breakpoint can not set on elif line,need set bp next line
	if ( $key eq 'elif' ) {	
		#read next line till it a valid line
		while ( $new_line = <FILE> ) {
			#checkLineNo();
		    last if ( $new_line !~ /^\s*#|^\s*$/o );
		}
		$linenum     = $.;
		$IsFromElsIf = 1;
	}
	
	#print $linenum, "\t", $line, "--\n";
	if ( $line =~ m/$Table_TYPE_PATTERN/o ) {
	    my $ret_str = process_table_search( $1, $2 );
		unless($ret_str eq '') {
		    generateBp($linenum, $ret_str);
		}
	}

	if ( $IsFromElsIf == 1 ) {
	    $IsFromElsIf = 0;
	    if (   $BP_LVL >= 3
	        && $new_line =~ /^\s*return(.*)$/o )
	    {
	        parse_statement_return($1);
	    }
	}

	return 0;
}

sub parse_statement_table {
	my ($line) = @_;
	my $linenum = $.;
	my $new_line = "";
	
	trim_string($line);
    #get One Whole Line of if
    while ( $new_line = <FILE> ) {
    	#checkLineNo();
        next if ( $new_line =~ /^\s*#|^\s*$/o );
        last if ( $new_line =~ /^\s*(if|test)/o );
        trim_string($new_line);
        $line = $line . $new_line;
    }

    if ( $line =~ m/$Table_TYPE_PATTERN/o ) {
        my $ret_str = process_table_search( $1, $2 );
        next if $ret_str eq '';
        unless($ret_str eq '') {
		    generateBp($linenum, $ret_str);
		}
    }
    
    return;
}

# only parse return in def_function
sub parse_statement_return {
	my ($line) = @_;
	my $linenum = $.;
	my $new_line = "";
	my $myline = "";

	if ($scope{"def_function"} eq "default") {
		return 0;
	}

	if (index( $line, '(' ) >= 0) {
	    while ( Is_Brace_Match($line) == 0 && ( $new_line = <FILE> ) ) {
			#checkLineNo();
	        next if ( $new_line =~ /^\s*#|^\s*$/o );
	        trim_string($new_line);
	        $line .= $new_line;
	    }
	}

	my $ret_str = process_function_return( 'return', $line, 1);
	unless ($ret_str eq '') {
		generateBp($linenum, $ret_str);
	}

	return 0;
}

#print process_function_return ('return', "cuonter(15)# (hahah)", 1)."\n";
#print process_function_return ('return', "(\"####\")", 1)."\n";
#print process_function_return ('return', "cuonter(15) # (hahah)", 1)."\n";

#exit 0;
sub checkLineNo {
	my $linenum = $.;
	return ;
	if ($linenum == 0) {
		closeFile();
		exit 0;
	} else {
		print "$linenum\n";
	}
}

#-------------------------
# parseCommand
#-------------------------
sub parseCommand {
	my $conf = "";
	p_error("Err0: pls specify the parameter\n -f src_FILE or\n -spa SPA_NAME\n")
		if ( $#ARGV < 1 );

	$conf = "bp.cnf";
	unless ($args{"-spf"} eq '') {
		genBpCnf($conf);
		print "generate genbpN configur file:$conf\n";
		exit 0;
	}

	#get target source file
	$Inputfile = $args{"-f"};
	if ( !$Inputfile ) {
	    $Inputfile = $args{"-spa"};
	
	    p_error("Err1: pls specify the parameter\n -f FILE or\n -spa SPANAME\n")
	      if ( !$Inputfile );
	
	    #open source from $MYNODE src path
	    #print "$MYNODE/sn/sps/$Inputfile/$Inputfile.src";
	    open( FILE, "$MYNODE/sn/sps/$Inputfile/$Inputfile.src" )
	      || p_error("Err: can not open the file $Inputfile, pls re-check!!\n");
	}
	else {
	
	    #open source from determined path
	    if ( -f "$Inputfile" ) {
	        open( FILE, "$Inputfile" )
	          || p_error("Err: can not open $Inputfile, pls re-check!!\n");
	    }
	    elsif ( -f "./$Inputfile" ) {
	        open( FILE, "./$Inputfile" )
	          || p_error("Err: can not open $Inputfile, pls re-check!!\n");
	    }
	    else {
	        p_error("Err: Can not open $Inputfile, pls re-check!!\n");
	    }
	}

	$Is_EPAY = 1 if ( $Inputfile =~ /EPAY/oi );

	#get BP level
	$BP_LVL = $args{'-l'};
	if ($BP_LVL) {
	    $BP_LVL = 1 if ( $BP_LVL < 1 );
	    $BP_LVL = 3 if ( $BP_LVL > 3 );
	    $BP_Level = $BP_LVL;
	}
	#print "$BP_Level $BP_LVL\n";	
	#get BP bp file path
	$BP_F = $args{'-o'};
	if ( $BP_F && open( OUTPUT, ">$BP_F" ) ) {
	    $BP_File = $BP_F;
	}
	else {
	    $BP_File = "spa.bp";
	    open( OUTPUT, ">$BP_File" )
	      || die "Err: Can not open object bpfile $BP_File\n";
	}
}

sub header {
	my $total = @ALL_BP;
	my $BP_Type = "";
	
	if ( $BP_Level >= 1 ) {
	    $BP_Type = 'TableSearch';
	}
	if ( $BP_Level >= 2 ) {
	    $BP_Type .= ' + FunctionDef';
	}
	if ( $BP_Level >= 3 ) {
	    $BP_Type .= ' + FunctionRet';
	}
	
	#my $c_date = `date`;
	#$c_date =~ tr/\n//d;
	my $c_date = "";
	my $Head = <<EOF
#--------------------------------#
# BP For SRC: $Inputfile
# BP Type   : $BP_Type
# BP Number : $total
# Gen Date  : $c_date
# BP file generated by genbpN 
#--------------------------------#

EOF
  ;

	print OUTPUT $Head;
}

sub commonbp {
	print OUTPUT @ALL_BP;
}

sub extensionBp {
	my $point = 0;

	genLineBp();
	changeGlobal();
}

sub changeGlobal {
	my $var = "";

	foreach $var (@GlobalVar) {
		changeGlobalVarByValue($var, $GlobalVarValue{$var});
	}
}

sub saveGlobalVar {
	my ($var, $val) = @_;
	
	$GlobalVarOpen{$var} = 1;
	$GlobalVarValue{$var} = $val;
}

sub changeGlobalVarByValue {
	my ($var, $val) = @_;
	my $str = "set $var = $val";
	$str = $str;

	if ($GlobalVarOpen{$var} == 1) {
		#print $str."\n";
		print OUTPUT $str."\n";
		return 0;
	}

	print "\n[Q:] $GlobalVarTitle{$var}\n";
	print "-----------------------------------------\n";
	print $str."\n";
	print "-----------------------------------------\n";
	print "\n[Y/N, Enter is y]";
	my $answer = <STDIN>;
	if ($answer =~/^\s*$/o || $answer =~ /^\s*(y|Y)/o) {
		#print $str."\n";
		print OUTPUT $str."\n";
	}

	return 0;
}

sub genLineBp {
	my $count	= @CodePoint;
	my $max		= 3000000;
	my $offset1	= 0;
	my $offset2	= 0;	
	my $idx		= 0;

	push(@CodePoint, $max);
	while ($idx < $count) {
		$offset1 = $CodePoint[$idx];
		$offset2 = $CodePoint[$idx + 1];
		genLineBpByOffset($offset1, $offset2);
		
		# move on 2 steps
		$idx = $idx + 2;
	}
}

sub genLineBpByOffset {
	my ($start, $end) = @_;
	my $str = "at $start..$end print(\"at_line: \",\$at_line) end at";
	#print $str."\n";
	print OUTPUT $str."\n";
}

sub tail {
	my $dir_name = dirname($BP_File);
	$dir_name = getcwd if $dir_name eq '.';
	my $totalnum = @ALL_BP;
	my $base_name = basename($BP_File);
	my $Full_BP_File = File::Spec->catfile( $dir_name, $base_name );
	printf("\n Done. Common Total BPs: %d\n", $totalnum);
	my $CMD_OUT = <<EOF
 -----------------------------------------
 You can run fllowing command in debug:spa console:
 source \"$Full_BP_File\"
 -----------------------------------------
 Enjoy it!
EOF
  ;
	print $CMD_OUT;
}


sub loadFile {
	my ($array, $file) = @_;
	unless(open(LOADFILE, "< $file" )) {
		#inf_print("can not open $file!");
		return -1;
	}
	
	@$array = <LOADFILE>;
	close(LOADFILE);	
	return 0;
}

sub checkSkip {
	my ($type) = @_;
	my $str = getScope($type);
	my $linenum = $.;
	
	if ($skip{$str} == 1) {
		push(@CodePoint, $linenum);
	}
}

sub setScope {
	my ($type, $name) = @_;	
	$scope{$type} = $name;
	checkSkip($type);
}

sub resetScope {
	my ($type) = @_;	
	checkSkip($type);
	$scope{$type} = "default";
}

sub getScope {
	my ($type) = @_;
	return $scope{"fsm"}." ".$scope{"state"}." ".$scope{$type};
}

sub printScope {
	my ($type) = @_;
	print $scope{"fsm"}." ".$scope{"state"}." ".$scope{$type};
}


sub saveSkipLineBpFunc {
	my ($type) = @_;
	$type =~ s/\s+/ /g;
	$skip{$type} = 1;
}

sub genBpCnf {
	my ($file) = @_;
	if (-f $file) {
		print "$file exists, check it by yourself.\n";
		return 0;
	}

	unless(open(BP, "> $file")) {
		print "can not open $file";
		return -1;
	}
	my $context = <<EOFBP
# used for genbpN
# version 0.1

# disable function bp
functions = {
	# add function by yourself
	# e.g.  fsm state funcion
}

# changed global variable
globalvars = {
	# add global variable by yourself
	# e.g.   glb_var = 1
}
EOFBP
  ;

	print BP $context;
	close(BP);	
	return 0;
}

sub config {
	my @configuration = ();
	my $position = 0;
	my $line = "";
	return		if (loadFile(\@configuration, "bp.cnf") != 0);
	
	LOOP:for($position = 0; $position < @configuration; $position ++) {
		$line = $configuration[$position];
		#print $line;
		if ($line =~ /^\s*(#.*)?$/o) {
			next LOOP;
		} elsif ($line =~ /^\s*functions\s*=\s*{/o) {
			$position = saveLineScope(\@configuration, $position);
		} elsif ($line =~ /^\s*globalvars\s*=\s*{/o) {
			$position = saveGlobal(\@configuration, $position);
		}
	}
}

sub saveGlobal {
	my ($array, $start) = @_;
	my $position = $start;
	my $line = "";

	#print "[$start] Global\n";
	LOOP:for($position = $start + 1; $position < @$array; $position ++) {
		$line = $$array[$position];
		#print $line;
		if ($line =~ /^\s*(#.*)?$/o) {
			next LOOP;
		} elsif ($line =~ /^\s*([\w!]+)\s*=\s*([\d]+)/o) {
			$position = saveGlobalVar($1, $2);
		} elsif ($line =~ /^\s*}/o) {
			last LOOP;
		}
	}

	return $position;
}

sub saveLineScope {
	my ($array, $start) = @_;
	my $position = $start;
	my $line = "";

	#print "[$start] Line Scope\n";
	LOOP:for($position = $start + 1; $position < @$array; $position ++) {
		$line = $$array[$position];
		#print $line;
		if ($line =~ /^\s*(#.*)?$/o) {
			next;
		} elsif ($line =~ /^\s*([\w!]+\s*[\w!]+\s*[\w!]+)/o) {
			$position = saveSkipLineBpFunc($1);
		} elsif ($line =~ /^\s*}/o) {
			last LOOP;
		}
	}

	return $position;
}

# main
sub main {
	# files will be opened in parseCommand
	parseCommand();
	config();

	parsing();

	# generates bp
	header();
	commonbp();
	extensionBp();
	tail();
	
	closeFile();
}

main();
