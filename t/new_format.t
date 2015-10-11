#!/gsc/bin/perl 
use strict; 
use Test::More qw/no_plan/;
use FindBin qw($Bin);
use WashU::Billing::Controller;
use List::AllUtils qw(uniq);

my $int_file = $Bin. "/data/FY16_billing_template_test.xlsx";
#my $ext_file = $Bin. "/data/External_Invoice.xlsx";

my $controller;
$controller = WashU::Billing::Controller->new( spreadsheet => $int_file);
ok($controller, "got internal controller");

my @int = $controller->get_internal_invoice_units;
ok(@int, 'got internal invoice units');

my $string =$controller->generate_internal_invoice(invoice_sequence => 1, format => 'none');
my $length = length($string);
ok($string, "got output string");
my $expected = 62856;
ok($length == $expected, "length is $length and expecting $expected");

my @rows = split("\n", $string);

ok(scalar(@rows) == 776, "row count is 776 " );

my @row_length = uniq map{length($_)} @rows;
ok(scalar(@row_length) == 1 , "all rows same number of characters");

ok($row_length[0] == 80, "number of characters per row is 80");

# $controller = WashU::Billing::Controller->new( spreadsheet => $ext_file);
# ok($controller, "got external controller");

# my @ext = $controller->get_external_invoice_units;
# ok(@ext, "got external invoices");
# ok(scalar(@ext) == 5, "number of invoices is 5" );

# my $i;
# for my $ext ( @ext) {
    # my $file = $controller->generate_external_invoice(invoice_unit => $ext, invoice_sequence => ++$i);
    # ok(($file and -e $file and -s $file), "file $file exists and is non-zero size"); 
    # unlink $file if -e $file;
# }
