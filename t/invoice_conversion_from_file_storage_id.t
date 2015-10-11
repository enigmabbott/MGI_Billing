#!/gsc/bin/perl 
use strict; 
use Test::More qw/no_plan/;
use FindBin qw($Bin);
use WashU::Billing::Controller;
use List::AllUtils qw(uniq);
use Storable;


my $file = $Bin. "/data/Billing.storable";
my $var = Storable::retrieve($file);  

my $controller = WashU::Billing::Controller->new( file_content => $$var, file_content_type => "xlsx");
ok($controller, "got controller");

my @int = $controller->get_internal_invoice_units;
ok(@int, 'got internal invoice units');

my $string =$controller->generate_internal_invoice(invoice_sequence => 1, format => 'none');
my $length = length($string);
ok($string, "got output string");
my $expected = 45036;
ok($length == $expected, "length is $length and expecting $expected");

my @rows = split("\n", $string);

$expected =556;
ok(scalar(@rows) == $expected, "row count is $expected(" . scalar(@rows) . ")" );

my @row_length = uniq map{length($_)} @rows;
ok(scalar(@row_length) == 1 , "all rows same number of characters");

ok($row_length[0] == 80, "number of characters per row is 80");


my @ext = $controller->get_external_invoice_units;
ok(@ext, "got external invoices");
$expected =5;
ok(scalar(@ext) == $expected, "number of invoices is $expected (". scalar(@ext) . ")" );

my $i;
for my $ext ( @ext) {
    my $file = $controller->generate_external_invoice(invoice_unit => $ext, invoice_sequence => ++$i);
    ok(($file and -e $file and -s $file), "file $file exists and is non-zero size"); 
#    unlink $file if -e $file;
}
