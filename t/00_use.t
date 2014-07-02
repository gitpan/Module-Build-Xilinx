use Test::More;

BEGIN {
    use_ok('Module::Build::Xilinx');
}

my $b = new_ok('Module::Build::Xilinx', [
        dist_name => 'dflipflops',
        dist_version => '0.01',
        proj_params => {
            family => 'spartan3a',
            device => 'xc3s700a',
            package => 'fg484',
            speed => -4,
        },
        tcl_script => 'program_test.tcl',
    ]);
is($b->module_name, 'Module::Build::Xilinx', 'module name is valid');
is($b->proj_ext, '.xise', 'project extension is as expected');
is($b->proj_name, $b->dist_name, 'project name is as expected');
is($b->tcl_script, 'program_test.tcl', 'tcl script is as expected');

SKIP: {
    skip 'only run this if you are a developer of the module by setting DEVONLY', 3 unless $ENV{DEVONLY};
    ok($b->create_build_script, "build script is created");
    isnt($b->dispatch('build'), undef, "dispatch of the 'build' action is done");
    isnt($b->dispatch('clean'), undef, "build is cleaned");
}
done_testing();

__END__
#### COPYRIGHT: 2014. Vikas N Kumar. All Rights Reserved
#### AUTHOR: Vikas N Kumar <vikas@cpan.org>
#### DATE: 30th June 2014
