package Module::Build::Xilinx;
use base 'Module::Build';

use strict;
use warnings;
use Carp;

our $VERSION = '0.01';
$VERSION = eval $VERSION;

# project name property
__PACKAGE__->add_property('proj_name', undef);
# project extension property
__PACKAGE__->add_property('proj_ext', '.xise');
# project parameters related to the device
__PACKAGE__->add_property('proj_params',
    default => sub { {} },
    # this check thing doesnt work
    check => sub {
        if (ref $_ eq 'HASH') {
            return 1 if (defined $_->{family} and defined $_->{device});
            shift->property_error(
                qq{Property "proj_params" needs "family" and "device" defined});
        } else {
            shift->property_error(
                qq{Property "proj_params" should be a hash reference.});
        }
        return 0;
    },
);
# testbench toplevel name
__PACKAGE__->add_property('tb_toplevel', 'testbench');
# testbench project
__PACKAGE__->add_property('tb_project', 'testbench.prj');
# testbench exe name
__PACKAGE__->add_property('tb_exe', 'testbench.exe');
# testbench library name. can this be something else ?
__PACKAGE__->add_property('tb_lib', 'work');
# testbench command file
__PACKAGE__->add_property('tb_cmd', 'simulate.cmd');
# testbench wdb file
__PACKAGE__->add_property('tb_wdb', 'testbench.wdb');
# source files
__PACKAGE__->add_property('source_files', []);
# testbench files
__PACKAGE__->add_property('testbench_files', []);
# tcl file
__PACKAGE__->add_property('tcl_script', 'program.tcl'); 

sub new {
    my $class = shift;
    # build the M::B object
    # hide the warnings about module_name
    my $self = $class->SUPER::new(module_name => $class, @_);
    my $os = $self->os_type;
    croak "No support for OS" unless $os =~ /Windows|Linux|Unix/i;
    croak "No support for OS" if $os eq 'Unix' and $^O !~ /linux/i;
    # adjust the build directory
    $self->blib('_build_' . $self->dist_name);
    $self->libdoc_dirs([]);
    $self->bindoc_dirs([]);
    # sanitize proj_params
    my $pp = $self->proj_params;
    $pp->{language} = 'VHDL' unless defined $pp->{language};
    $pp->{language} = uc $pp->{language};
    croak $pp->{language} . " not supported" unless $pp->{language} eq 'VHDL';
    $self->proj_params($pp);
    # project name can just be dist_name
    $self->proj_name($self->dist_name);
    # add the VHDL files as build files
    $self->add_build_element('vhd');
    # add the testbench files as well
    $self->add_build_element('vhdtb');
    # add the ucf files as build files
    $self->add_build_element('ucf');
    $self->add_to_cleanup($self->tcl_script) if defined $self->tcl_script;
    return $self;
}

sub ACTION_build {
    my $self = shift;
    # build invokes the process_*_files() functions
    $self->SUPER::ACTION_build(@_);
    my $tcl = $self->tcl_script;
    $self->log_info("Generating the $tcl script\n");
    if ($self->verbose) {
        require Data::Dumper;
        local $Data::Dumper::Terse = 1;
        my ($a, $b) = Data::Dumper->Dumper($self->source_files);
        $self->log_verbose("source files: $b");
    }
    # add the tcl code
    open my $fh, '>', $tcl or croak "Unable to open $tcl for writing: $!";
    print $fh $self->_dump_tcl_code();
    close $fh;
    1;
}

sub process_ucf_files {
    my $self = shift;
    my $regex = qr/\.(?:ucf)$/;
    my @filearray = ();
    foreach my $dir (qw/lib src/) {
        next unless -d $dir;
        my $files = $self->rscan_dir($dir, $regex);
        push @filearray, @$files if ref $files eq 'ARRAY' and scalar @$files;
    }
    # make unique
    my %fh = map { $_ => 1 } @filearray;
    $self->source_files([@{$self->source_files}, keys %fh]);
}

sub process_vhd_files {
    my $self = shift;
    my $regex = qr/\.(?:vhd|vhdl)$/;
    my @filearray = ();
    foreach my $dir (qw/lib src/) {
        next unless -d $dir;
        my $files = $self->rscan_dir($dir, $regex);
        push @filearray, @$files if ref $files eq 'ARRAY' and scalar @$files;
    }
    # make unique
    my %fh = map { $_ => 1 } @filearray;
    $self->source_files([@{$self->source_files}, keys %fh]);
}

sub process_vhdtb_files {
    my $self = shift;
    ## patterns taken from $Xilinx/data/projnav/xil_tb_patterns.txt
    my $regex = 
        qr/(?:_tb|_tf|_testbench|_tb_[0-9]+|databench\w*|testbench\w*)\.(?:vhd|vhdl)$/;
    my @filearray = ();
    foreach my $dir (qw/lib src t tb/) {
        next unless -d $dir;
        my $files = $self->rscan_dir($dir, $regex);
        push @filearray, @$files if ref $files eq 'ARRAY' and scalar @$files;
    }
    # make unique
    my %fh = map { $_ => 1 } @filearray;
    $self->testbench_files([@{$self->testbench_files}, keys %fh]);
}

sub _dump_tcl_code {
    my $self = shift;
    my $projext = $self->proj_ext;
    my $projname = $self->proj_name;
    my $dir_build = $self->blib;
    my $src_files = join(' ', @{$self->source_files});
    my $tb_files = join(' ', @{$self->testbench_files});
    my $tb_prj = $self->tb_project;
    my $tb_exe = $self->tb_exe;
    my $tb_top = $self->tb_toplevel;
    my $tb_lib = $self->tb_lib;
    my $tb_cmd = $self->tb_cmd;
    my $tb_wdb = $self->tb_wdb;
    my %pp = %{$self->proj_params};
    $pp{family} = $pp{family} || 'spartan3a';
    $pp{device} = $pp{device} || 'xc3s700a';
    $pp{package} = $pp{package} || 'fg484';
    $pp{speed} = $pp{speed} || '-4';
    $pp{language} = $pp{language} || 'VHDL';
    $pp{devboard} = $pp{devboard} || 'Spartan-3A Starter Kit';
    my $vars = << "TCLVARS";
# input parameters start here
set projext {$projext}
set projname {$projname}
set dir_build $dir_build
# Tcl arrays are associative arrays. We need these parameters set in order hence
# we use integers as keys to the parameters
# the following can be retrieved by running the command partgen -arch spartan3a
# this allows the same UCF file used in multiple projects as long as the
# constraint names stay the same
array set projparams {
    0 {family $pp{family}}
    1 {device $pp{device}}
    2 {package $pp{package}}
    3 {speed $pp{speed}}
    4 {"Preferred Language" $pp{language}}
    5 {"Evaluation Development Board" "$pp{devboard}"}
    6 {"Allow Unmatched LOC Constraints" true}
    7 {"Write Timing Constraints" true}
}
# test bench file names matter ! Refer \$Xilinx/data/projnav/xil_tb_patterns.txt
# it has to end in _tb/_tf or should be named testbench
# the constraint file and test bench go together for simulation purposes
set src_files [list $src_files]
set tb_files [list $tb_files]
set tb_prj {$tb_prj}
set tb_exe {$tb_exe}
set tb_top {$tb_top}
set tb_lib {$tb_lib}
set tb_cmd {$tb_cmd}
set tb_wdb {$tb_wdb}

TCLVARS
    my $basecode = << 'TCLBASE';
# main code starts here
#
proc add_parameter {param value} {
    puts stderr "INFO: Setting $param to $value"
    if {[catch {xilinx::project set $param $value} err]} then {
        puts stderr "WARN: Unable to set $param to $value\n$err"
        return 1
    }
    return 0
}

proc add_parameters {plist} {
    array set params $plist
    foreach idx [lsort [array names params]] {
        set param [lindex $params($idx) 0]
        set value [lindex $params($idx) 1]
        add_parameter $param $value
    }
    return 0
}
# we have a separate function for adding source and testbench
proc add_source_file {ff} {
    if {[file exists $ff]} then {
        set found [xilinx::search $ff -regexp -type file]
        if {[xilinx::collection sizeof $found] == 0} then {
            puts stderr "INFO: Adding $ff"
            if {[catch {xilinx::xfile add $ff} err]} then {
                puts stderr "ERROR: Unable to add $ff\n$err"
                exit 1
            }
        } else {
            puts stderr "INFO: $ff already in project"
        }
    } else {
        puts stderr "WARN: $ff does not exist"
    }
}

proc add_testbench_file {ff} {
    set viewname Simulation
    if {[file exists $ff]} then {
        set found [xilinx::search $ff -regexp -type file]
        if {[xilinx::collection sizeof $found] == 0} then {
            puts stderr "INFO: Adding $ff to $viewname"
            if {[catch {xilinx::xfile add $ff -view $viewname} err]} then {
                puts stderr "ERROR: Unable to add $ff\n$err"
                exit 1
            }
        } else {
            puts stderr "INFO: $ff already in project"
        }
    } else {
        puts stderr "WARN: $ff does not exist"
    }
}

proc process_run_task {task} {
    if {[catch {xilinx::process run $task} err]} then {
        puts stderr "ERROR: Unable to run $task\n$err"
        return 1
    }
    return 0
}    

proc simulation_create {prj exe topname} {
    if {[catch {exec fuse -incremental $topname -prj $prj -o $exe} err]} then {
        puts stderr "ERROR: Unable to run fuse for $prj\n$err"
        return 1
    }
    return 0
}

proc simulation_run {exe cmd wdb} {
    if {[catch {exec $exe -tclbatch $cmd -wdb $wdb} err]} then {
        puts stderr "ERROR: Unable to run $exe with $cmd\n$err"
        return 1
    }
    return 0
} 

proc simulation_view {wdb} {
    if {[catch {exec isimgui -view $wdb} err]} then {
        puts stderr "ERROR: Unable to view $wdb\n$err"
        return 1
    }
    return 0
}

proc program_device {bitfiles ipf} {
    set cmdfile program_device.cmd
    if {[catch {set fd [open $cmdfile w]} err]} then {
        puts stderr "ERROR: Unable to open $cmdfile for writing\n$err"
        return 1
    }
    puts $fd "setLog -file program_device.log"
    puts $fd "setPreference -pref UserLevel:Novice"
    puts $fd "setPreference -pref ConfigOnFailure:Stop"
    puts $fd "setMode -bscan"
    puts $fd "setCable -port auto"
    puts $fd "identify"
    for {set idx 0} {$idx < [llength $bitfiles]} {incr idx} {
        set bitf [lindex $bitfiles $idx]
        set ii [expr $idx + 1]
        # we use assignFile over addDevice since it allows over-writing
        puts $fd "assignFile -p $ii -file \"$bitf\""
    }
    for {set idx 0} {$idx < [llength $bitfiles]} {incr idx} {
        set ii [expr $idx + 1]
        puts $fd "program -p $ii"
    }
    puts $fd "checkIntegrity"
    puts $fd "saveprojectfile -file \"$ipf\""
    puts $fd "quit"
    catch {close $fd}
    if {[catch {exec impact -batch "./program_device.cmd"} err]} then {
        #TODO: check log here for errors
        puts stderr "ERROR: Unable to run impact to program the device"
        return 1
    }
    return 0
}

proc cleanup_and_exit {xise bdir errcode} {
    if {[catch {xilinx::project close} err]} then {
        puts stderr "WARN: error closing $xise\n$err"
        exit 1
    } else {
        puts stderr "INFO: Closed $xise"
    }
    cd $bdir
    exit $errcode
}

set mode_setup 0
set mode_build 0
set mode_simulate 0
set mode_view 0
set mode_program 0
set mode_clean 0
set device_name ""

proc print_usage {appname} {
    puts stderr "$appname \[OPTIONS\]\n"
    puts stderr "OPTIONS are any or all of the following:"
    puts stderr "-setup\t\t\tCreates/Opens the project and adds parameters, files"
    puts stderr "-build\t\t\tBuilds the project and generates bitstream"
    puts stderr "-simulate\t\tSimulates the generated bitstream"
    puts stderr "-view\t\t\tView the simulation output using isimgui"
    puts stderr "-all\t\t\tAlias for '-clean -setup -build -simulate'"
    puts stderr "-clean\t\t\tCleans the project. Has highest precedence"
    puts stderr "-program \[dev\]\t\tProgram the device given"
    exit 1
}

if { $argc > 0 } then {
    for {set idx 0} {$idx < $argc} {incr idx} {
        set opt [lindex $argv $idx]
        if {$opt == "-setup"} then {
            set mode_setup 1
        } elseif {$opt == "-build"} then {
            set mode_build 1
        } elseif {$opt == "-simulate"} then {
            set mode_simulate 1
        } elseif {$opt == "-view"} then {
            set mode_view 1
        } elseif {$opt == "-clean"} then {
            set mode_clean 1
        } elseif {$opt == "-all"} then {
            set mode_clean 1
            set mode_setup 1
            set mode_build 1
            set mode_simulate 1
        } elseif {$opt == "-program"} then {
            set mode_program 1
            incr idx
            if {$idx < $argc} then {
                set device_name [lindex $argv $idx]
            } else {
                puts stderr "WARN: device name not given."
            }
        } else {
            print_usage $argv0
        }
    }
} else {
    print_usage $argv0
}

set projfile $projname$projext
set basedir [pwd]
set builddir $basedir/$dir_build
set srcdir $builddir/../
set tbdir $builddir/../
catch {exec mkdir $builddir}
cd $builddir
puts stderr "INFO: In $builddir"

if {[file exists $projfile]} then {
    if {[catch {xilinx::project open $projname} err]} then {
        puts stderr "ERROR: Could not open $projfile for reading\n$err"
        exit 1
    }
    puts stderr "INFO: Opened $projfile"
    if {$mode_clean == 1} then {
        if {[catch {xilinx::project clean} err]} then {
            puts stderr "WARN: Unable to clean $projfile\n$err"
        }
        # since we cleaned, we need to setup first
        set mode_setup 1
    }
} else {
    # force setup mode
    set mode_setup 1
    if {[catch {xilinx::project new $projname} err]} then {
        puts stderr "ERROR: Unable to create $projfile\n$err"
        exit 1
    }
    puts stderr "INFO: Created $projfile"
}

# check if other options need to be set
set prj_files [glob -nocomplain -tails -directory $builddir $tb_prj]
set bit_files [glob -nocomplain -tails -directory $builddir *.bit]
set wdb_files [glob -nocomplain -tails -directory $builddir $tb_wdb]
# if view/program is set and simulate is not then check and set
if {[llength $wdb_files] < 1 && $mode_simulate == 0} then {
    if {$mode_view == 1 || $mode_program == 1} then {
        set mode_simulate 1
        puts stderr "INFO: No wdb's found in $builddir so running simulate"
    }
}
# if simulate is set and build is not then check and set
if {[llength $bit_files] < 1 && $mode_simulate == 1 && $mode_build == 0} then {
    set mode_build 1
    puts stderr "INFO: No bitstreams found in $builddir so running build"
}
# if build is set and setup is not then check and set
if {[llength $prj_files] < 1 && $mode_build == 1 && $mode_setup == 0} then {
    set mode_setup 1
    puts stderr "INFO: No setup files found in $builddir so running setup"
}

if {$mode_setup == 1} then {
    # perform setting of the project parameters
    add_parameters [array get projparams]
    # add source and testbench files
    # also create the prj file for simulation later
    if {[catch {set fd [open $tb_prj w]} err]} then {
        puts stderr "ERROR: Unable to open $tb_prj for writing\n$err"
        cleanup_and_exit $projfile $basedir 1
    }
    foreach fname $src_files {
        set ff $srcdir/$fname
        add_source_file $ff
        if {[string match *.ucf $fname]} then {
            puts stderr "INFO: Not adding $ff to $tb_prj"
        } else {
            puts $fd "vhdl $tb_lib \"$ff\""
        }
    }
    foreach fname $tb_files {
        set ff $tbdir/$fname
        add_testbench_file $ff
        if {[string match *.ucf $fname]} then {
            puts stderr "INFO: Not adding $ff to $tb_prj"
        } else {
            puts $fd "vhdl $tb_lib \"$ff\""
        }
    }
    catch {close $fd}
}
if {$mode_build == 1} then {
    if {[process_run_task "Check Syntax"]} then {
        cleanup_and_exit $projfile $basedir 1
    }
    if {[process_run_task "Implement Design"]} then {
        cleanup_and_exit $projfile $basedir 1
    }
    if {[process_run_task "Generate Programming File"]} then {
        cleanup_and_exit $projfile $basedir 1
    }
}
if {$mode_simulate == 1} then {
    # create the simulation executable
    set topname $tb_lib.$tb_top
    if {[simulation_create $tb_prj $tb_exe $topname]} then {
        cleanup_and_exit $projfile $basedir 1
    }
    # create the simulation command file
    if {[catch {set fd [open $tb_cmd w]} err]} then {
        puts stderr "ERROR: Unable to open $tb_cmd for writing\n$err"
        cleanup_and_exit $projfile $basedir 1
    }
    puts $fd "onerror \{resume\}"
    puts $fd "wave add /"
    puts $fd "run all"
    puts $fd "quit -f"
    catch {close $fd}
    set path2exe [pwd]/$tb_exe
    if {[simulation_run $path2exe $tb_cmd $tb_wdb]} then {
        cleanup_and_exit $projfile $basedir 1
    }
    puts stderr "INFO: simulation complete"
}
if {$mode_view == 1} then {
    if {[simulation_view $tb_wdb]} then {
        cleanup_and_exit $projfile $basedir 1
    }
}
if {$mode_program == 1} then {
    puts stderr "INFO: will try to program device $device_name"
    set ipf [pwd]/$projname.ipf
    set bit_files [glob -nocomplain -tails -directory $builddir *.bit]
    if {[program_device $bit_files $ipf]} then {
        cleanup_and_exit $projfile $basedir 1
    }
    # we should set the {iMPACT Project File} value
    add_parameter {iMPACT Project File} $ipf
    puts stderr "INFO: Done programming device $device_name"
}
# ok now cleanup and exit with 0
cleanup_and_exit $projfile $basedir 0

TCLBASE
    return << "TCLCODE";
### -- THIS PROGRAM IS AUTO GENERATED -- DO NOT EDIT -- ###
$vars

$basecode
TCLCODE
}

1;
__END__
#### COPYRIGHT: 2014. Vikas N Kumar. All Rights Reserved
#### AUTHOR: Vikas N Kumar <vikas@cpan.org>
#### DATE: 30th June 2014
