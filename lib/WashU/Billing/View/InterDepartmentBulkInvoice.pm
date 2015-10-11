package WashU::Billing::View::InterDepartmentBulkInvoice;

use Moose; 
use MooseX::StrictConstructor;
use Moose::Util::TypeConstraints;
use App::Path;

enum 'VALID_FORMAT' => qw(file stdout none);

has 'format' => (
    is => 'rw',
    isa => 'VALID_FORMAT',
    default => 'stdout'
);
        
has 'model' => (
    is => 'rw',
    isa => 'WashU::Billing::Model::InterDepartmentBulkInvoice',
    default => 'none'
);

sub file_name {
    my $dir = App::Path->tempdir;
    return $dir .'/GENOME_INSTITUTE_INVOICE.TXT'
}

sub to_string {join('',map{$_->to_string} @{shift->model->billing_records});}

sub generate {
    my $self = shift;

    my $string = $self->to_string;
    my $return_val;
    if($self->format eq 'stdout'){
        print $string;
        $return_val = $string;

    }elsif($self->format eq 'file'){
        $string =~ s/\n/\r\n/g; #washu billing needs windows carriage returns
        my $file = $self->file_name;
        open F , ">$file" or die "can't open file $file";
        print F $string;
        close F;
        $return_val = $file;
    }else {
        $return_val = $string;

    }

    return $return_val;
}
 
__PACKAGE__->meta->make_immutable;
1;
