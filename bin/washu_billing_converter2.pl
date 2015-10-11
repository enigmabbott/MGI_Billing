#!/gsc/bin/perl
use strict;
use WashU::Billing::Controller;
use Scalar::Util qw/looks_like_number/;
use GSCApp;
App->init;

my ($file) = @ARGV or die "need file";

if (looks_like_number($file)){
    my $fs = GSC::FileStorage->get($file);
    $file= $fs->write_file_storage_file;
    print "created: $file\n";
    my $str = "cp '$file' " . $ENV{HOME};
    `$str`;
    print $str . "\n";
}
my $controller = WashU::Billing::Controller->new( spreadsheet => $file);

my $file=$controller->generate_internal_invoice(invoice_sequence => 1, format => 'file');

if($file){
    print "created internal invoice: $file\n";
}else {
    print "DID NOT CREATE INTERNAL INVOICE... hope thats ok\n";
}

# my @ext = $controller->get_external_invoice_units;

# my @foo = (qw/
# 124830934
# 124830936
# 124830938
# 124830940
# /
# );


# my $i=0;

# for my $ext ( @ext) {
    # my $file = $controller->generate_external_invoice(invoice_unit => $ext, invoice_sequence => $foo[$i]);
    # $i++;
    # print "created external invoice: $file\n";
    # my $str = "cp '$file' ~/";
    # `$str`;
    # print $str . "\n";
 
# }
