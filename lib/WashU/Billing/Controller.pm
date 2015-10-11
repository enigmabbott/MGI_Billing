package WashU::Billing::Controller;
# ABSTRACT: turns baubles into trinkets

use Moose; 
use MooseX::StrictConstructor;
use Moose::Util::TypeConstraints;
use warnings FATAL => qw(all);
use DataAdapter;
use WashU::Billing::Model::AdapterBillingUnit;
use WashU::Billing::Model::AdapterBillingUnit::Internal;
use WashU::Billing::Model::InvoiceUnit;
use WashU::Billing::Model::InvoiceUnit::ProjectDepartmentID;
use WashU::Billing::Model::InterDepartmentBulkInvoice;
use WashU::Billing::View::InterDepartmentBulkInvoice;
use WashU::Billing::View::ExternalInvoice;
use WashU::Billing::MooseTypeLibrary qw(ValidFile);
use DataAdapter::Parser::CSV;
use DataAdapter::Parser::TSV;
use DataAdapter::Parser::XLS;
use DataAdapter::Parser::XLSX;
use DataAdapter::IO::FileInputStream;
use DataAdapter::IO::FileInputStream::XLSX;
use DataAdapter::IO::FileInputStream::XLS;

extends 'DataAdapter';

has 'format' => (isa => 'Str', is => 'rw', default => sub { return 'converted_isbillable_spreadsheet' });
 
has 'result_type' => ( isa => 'Str', is => 'rw', default => sub { return 'WashU::DataAdapter::Result::InvoiceUnit'; });

has 'invoice_units' => (
    is => 'rw',
    isa => 'ArrayRef[WashU::Billing::Model::InvoiceUnit]',
    lazy_build => 1
);

has 'spreadsheet' => (
    is => 'rw',
    isa => ValidFile,
    trigger => sub {my $s = shift; $s->input_stream($s->_build_input_stream);},
);

has 'file_content' => (
    is => 'rw',
    isa => 'Str',
    trigger => sub {my $s = shift; $s->input_stream($s->_build_input_stream);},
);

enum FILE_CONTENT_TYPE => qw(csv tsv xls xlsx);

has 'file_content_type' => (
    is => 'rw',
    isa => 'FILE_CONTENT_TYPE',
    lazy_build => 1,
);

has 'data_adapter_parser' => (
    is => 'rw',
    isa => 'DataAdapter::Parser',
    lazy_build => 1
);

has 'generate_invoice_sequence_from_pse' =>  (
    is => 'rw',
    isa => 'Bool',
    default => sub{ 0}
);

sub _build_data_adapter_parser {
    my $type = shift->file_content_type;
    $type= uc($type);
    my $package = "DataAdapter::Parser::$type";
    return $package->new;
}

sub _build_file_content_type {
    my $self = shift;
    my $spreadsheet = $self->spreadsheet or die "file_content_type must be declared if you aren't passing a spreadsheet";
    
    $spreadsheet =~ /\.([^\.]+)$/;
    return unless $1;
    return $1;
}

sub _build_input_stream {
    my $self = shift;
    my $parser = $self->data_adapter_parser; 

    my $package ='DataAdapter::IO::FileInputStream::' . uc($self->file_content_type);
    my %params = ( parser => $parser);

    if($self->spreadsheet){
       $params{file} = $self->spreadsheet;      
    }else {
        if($self->file_content_type ne 'xlsx'){
            die "Currently only xlsx spreadsheets are supported";
        }
        my $content = $self->file_content;
        $params{file_handle} = IO::File->new(\$content, 'r');

    }

    return $package->new( %params);
}

#invoice destination is external vs. internal
sub _build_invoice_units {
    my $self = shift;
    my %invoice_map;
    my $i = 0;
    my $j= 0;

    while ( my $data = $self->input_stream->next_result ) {
        return unless ($data);
        $j++;

        my %params = $self->generate_params($data);
        return unless (%params);
        unless($params{washu_deptnbr}){
        #    print Data::Dumper::Dumper \%params;
            die "washu_deptnbr is a required field at row: " . ($j + 1);
        }

        if($params{washu_deptnbr}  =~ /\D/){
            die "washu_deptnbr is a is non-numeric at row: " . ($j + 1)  . " with value: " . $params{washu_deptnbr};

        }
        my $class= 'WashU::Billing::Model::AdapterBillingUnit';
           $class .= ($params{washu_deptnbr} == 0) ? '' : '::Internal';

        my $obj = $class->new( format => $class, %params);

        my $key =$obj->invoice_group_by_string;

        unless($invoice_map{ $obj->invoice_destination }->{$key}->{order}){
            $invoice_map{ $obj->invoice_destination }->{$key}->{order} = ++$i;
        }

        push @{ $invoice_map{ $obj->invoice_destination }->{$key}->{row_data} }, $obj;
    }

    my @invoices; 

#can have only one internal invoice
    if ( $invoice_map{internal} ) {
        for my $invoice_key (
            sort {
                $invoice_map{internal}->{$a}->{order} <=> $invoice_map{internal} ->{$b}->{order}
            } keys %{ $invoice_map{internal} }
          ) {

            my $classm = 'WashU::Billing::Model::InvoiceUnit::ProjectDepartmentID';
            my $internal = $classm->new(
                format => $classm,
                row_data => $invoice_map{internal}->{$invoice_key}->{row_data},
                invoice_destination => 'internal',
            ) or die;
            push @invoices, $internal;
        }
    }

#multiple externals 
    if($invoice_map{external}){
            
        for my $invoice_key ( sort { $invoice_map{external}->{$a}->{order} <=> $invoice_map{external}->{$b}->{order} } keys %{ $invoice_map{external}}){
            my $classm = 'WashU::Billing::Model::InvoiceUnit';

            my $ext = $classm->new(
                format              => $classm,
                row_data            => $invoice_map{external}->{$invoice_key}->{row_data},
                invoice_destination => 'external',
            ) or die;
            push @invoices, $ext;
        }
    }

    return \@invoices;
}

sub get_external_invoice_units { grep {$_->invoice_destination eq 'external'} @{shift->invoice_units}; }
sub get_internal_invoice_units { grep {$_->invoice_destination eq 'internal'} @{shift->invoice_units}; }

sub generate_internal_invoice {
    my ($self, %p) = @_;
    my @inv = $self->get_internal_invoice_units or return;
    my $invoice_sequence = delete $p{invoice_sequence};
    die "required param invoice sequence omitted" unless $invoice_sequence;

    my $i;
    $_->invoice_sequence($invoice_sequence . "." . ++$i) for(@inv);

    my $model =WashU::Billing::Model::InterDepartmentBulkInvoice->new(project_department_ids => \@inv);
    my $view = WashU::Billing::View::InterDepartmentBulkInvoice->new(model => $model,%p);
    return $view->generate;
}

sub generate_external_invoice {
    my ($self, %p) = @_;
    my $invoice_unit = delete $p{invoice_unit};
    die "required param invoice_unit omitted" unless $invoice_unit;

    my $invoice_sequence = delete $p{invoice_sequence};
    die "required param invoice_sequence omitted" unless $invoice_sequence;

    unless($invoice_unit->invoice_sequence($invoice_sequence)){
        die "unable to set invoice sequence";
    }

    my $view = WashU::Billing::View::ExternalInvoice->new(model => $invoice_unit,%p);
    return $view->generate;
}

__PACKAGE__->meta->make_immutable;
1;
__END__
=pod

=head1 NAME

WashU::Billing::Controller

=head1 SYNOPSIS

my $controller = WashU::Billing::Controller->new( file_content => $string, file_content_type => "xlsx");

#or

my $controller = WashU::Billing::Controller->new( file => "myspreadsheet.xlsx");

my @int = $controller->get_internal_invoice_units;

my $string =$controller->generate_internal_invoice(invoice_sequence => 1, format => 'none');#format could be  'file'

my @ext = $controller->get_external_invoice_units;

my $i ; #Could be a pse_id

for my $ext ( @ext) {

    my $file_name = $controller->generate_external_invoice(invoice_unit => $ext, invoice_sequence => ++$i);

}

=head1 DESCRIPTION

see: https://gscweb.gsc.wustl.edu/wiki/Lims/Purpose/ProjectAdministration/PrepareProjectInvoice


=head1 METHODS

=head2 get_external_invoice_units  grep $_->invoice_destination eq 'external'} @shift->invoice_units}; }

=cut

=head2 get_internal_invoice_units  grep $_->invoice_destination eq 'internal'} @shift->invoice_units}; }

=cut

=head2 generate_internal_invoice 

=cut

=head2 generate_external_invoice 

=cut

=head1 Moose ATTRIBUTES

=head2 format 

=cut

=head2 result_type 

=cut

=head2 invoice_units 

=cut

=head2 spreadsheet 

=cut

=head2 file_content 

=cut

=head2 file_content_type 

=cut

=head2 data_adapter_parser 

=cut

=head2 generate_invoice_sequence_from_pse 

=cut

