#!/gsc/bin/perl 
use strict; 
use Test::More;
use FindBin qw($Bin);
use WashU::Billing::Controller;
use List::AllUtils qw(uniq);

my $int_file = $Bin. "/data/Internal_Invoice.xlsx";
my $ext_file = $Bin. "/data/External_Invoice.xlsx";

my $controller;
$controller = WashU::Billing::Controller->new( spreadsheet => $int_file);
ok($controller, "got internal controller");

my @int = $controller->get_internal_invoice_units;
ok(@int, 'got internal invoice units');

my $string =$controller->generate_internal_invoice(invoice_sequence => 1, format => 'none');
my $length = length($string);
ok($string, "got output string");
my $expected = 62856;
is($length ,$expected, "length is $length and expecting $expected");

my @rows = split("\n", $string);

is(scalar(@rows) , 776, "row count is as expected " );

my @row_length = uniq map{length($_)} @rows;
is(scalar(@row_length) , 1 , "all rows same number of characters");

is($row_length[0] , 80, "number of characters per row match");

$controller = WashU::Billing::Controller->new( spreadsheet => $ext_file);
ok($controller, "got external controller");

my @ext = $controller->get_external_invoice_units;
ok(@ext, "got external invoices");
ok(scalar(@ext) == 5, "number of invoices is 5" );

my $i;
for my $ext ( @ext) {
    my $file = $controller->generate_external_invoice(invoice_unit => $ext, invoice_sequence => ++$i);
    ok(($file and -e $file and -s $file), "file $file exists and is non-zero size"); 
    unlink $file if -e $file;
}

&done_testing();
