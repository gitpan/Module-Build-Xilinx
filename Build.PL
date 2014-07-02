use strict;
use warnings;
use Module::Build;

my $build = Module::Build->new(
    module_name => 'Module::Build::Xilinx',
    license => 'mit',
    dist_author => 'Vikas N Kumar <vikas@cpan.org>',
    dist_abstract => <<ABSTRACT,
Module::Build::Xilinx generates Tcl scripts to create and build Xilinx ISE projects
and can compile VHDL files present in the lib/ directory.
ABSTRACT
    create_readme => 0,
    create_license => -e 'LICENSE' ? 0 : 1,
    configure_requires => {
        'Module::Build' => 0,
        'Software::License' => 0,
    },
    build_requires => {
        'Module::Build' => 0,
        'Test::More' => 0,
    },
    requires => {
        'Module::Build' => 0,
    },
    dynamic_config => 1,
    pm_files => {
        'lib/Module/Build/Xilinx.pm' => 'lib/Module/Build/Xilinx.pm',
    },
    share_dir => 'share',
    recurse_into => undef,
);

$build->create_build_script;
$build->dispatch('clean');
$build->dispatch('distmeta');
$build->dispatch('manifest');

__END__
#### COPYRIGHT: 2014. Vikas N Kumar. All Rights Reserved
#### AUTHOR: Vikas N Kumar <vikas@cpan.org>
#### DATE: 30th June 2014
#### LICENSE: Refer LICENSE file.
