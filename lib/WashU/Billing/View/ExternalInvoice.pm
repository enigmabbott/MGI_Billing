package WashU::Billing::View::ExternalInvoice;

use Moose; 
use MooseX::StrictConstructor;
use Moose::Util::TypeConstraints;
use PDF::API2;
use PDF::Table;
use Data::Dumper;
use App::Path;

my $header_file = '/gsc/scripts/share/washu_billing/TGI_invoice_header_v1b.png';
my $footer_file = '/gsc/scripts/share/washu_billing/TGI_letterhead_main2.png';

sub max_itemized_rows {12; } 
has 'pdf_page' => (
    is => 'rw',
    isa => 'Object',
);

has 'pdf_g' => (
    is => 'rw',
    isa => 'Object',
);

has 'pdf_text' => (
    is => 'rw',
    isa => 'Object',
);

has 'pdf' => (
    is => 'ro',
    isa => 'Object',
    default => sub {  PDF::API2->new();} 
);

has 'model' => (
    is => 'rw',
    isa => 'WashU::Billing::Model::InvoiceUnit',
);

has 'invoice_header_data' => (
    is => 'rw',
    isa => 'ArrayRef',
    lazy_build => 1 
);

sub _build_invoice_header_data {
    my $self = shift;
    return
    [
        'PI: '. $self->model->primary_collaborator,
        'Attn: ' . $self->model->accounts_payable_contact,
        'Date: ' . $self->date,
        'Billing Period: ' . $self->billing_period,
        'MGI Invoice-NBR: ' . $self->model->invoice_sequence,
        'PO ID: ' . $self->model->ponbr, 
        'Project: '. $self->model->project_name
    ];
}

sub date {
    my $self = shift;
    $self->model->date =~ /(..)(..)(..)/;
    return "$1/$2/$3";
}

sub billing_period {
    my $self = shift;
     $self->model->date =~ /(..)..(..)/;
    return "$1/$2"; 
}

has 'itemized_list' => (
    is => 'rw',
    isa => 'ArrayRef',
    lazy => 1,
    default => sub {
        my  $self = shift; 

        my $i;
        
        my @data = @{$self->model->row_data};
        my @list = ( ['Activity', 'Description', 'Quantity', 'Rate' , 'Total' ]);


        for my $row (@data){
            push @list,[ $row->activity, $row->sample_description, $row->totalqty,'$'.  $row->rate,  "\$" . &commify(sprintf("%.2f",$row->billabletotal))];
        }

        push @list , ['','','', 'Invoice Total:','$'  . &commify(sprintf("%.2f",$self->model->invoice_amount))];

        return \@list; 
    },
);

sub init_page {
    my ($self) = @_;
    my $pdf = $self->pdf;
    my $page = $pdf->page();

    my $g = $page->gfx();

    my $header_image=$pdf->image_png($header_file);
    $g->image( $header_image, 50, 650,.22 );

    my $footer_image=$pdf->image_png($footer_file);
    $g->image( $footer_image, 75, 15,.25 );

    $g->strokecolor("#FF0000");

    $page->mediabox('Letter');
    my $text = $page->text();
    $text->translate(50, 630);

    $self->pdf_page($page);
    $self->pdf_g($g);
    $self->pdf_text($text);

    return 1;
}
 
sub generate {
    my ($self, %p) = @_;

    $self->init_page or return;
    $self->add_config_hash_to_pdf_page(size => 12 , font_name => 'Helvetica', data => $self->invoice_header_data, separate_by_space => -10) or return ;
    $self->add_invoice_items_to_page(size => 12, data => $self->itemized_list, separate_by_space => -30 ) or return; 
    $self->add_footer_to_pdf_page($self->invoice_footer_config) or return;

    $self->pdf_g->endpath();

# Save the PDF
    my $file = $self->resolve_file_name or return;
    $self->pdf->saveas($file) ;
    $self->pdf->end ;

    return $file;
}

sub add_config_hash_to_pdf_page {
    my ($self,%hash ) = @_;

    my $default_incr = -1 * $hash{size};
    $default_incr = -12  if $default_incr > -12;
    $self->pdf_text->font( $self->pdf->corefont($hash{font_name}),$hash{size});

    for my $string (@{$hash{data}}){
        $self->pdf_text->text($string);
        $self->pdf_text->cr( $string ? $default_incr : -5);
    }

    $self->pdf_text->cr($hash{separate_by_space});
    return 1;
}

sub add_invoice_items_to_page {
    my ($self, %hash) = @_;
    my $table = PDF::Table->new;
    my $header= shift (@{$hash{data}});
    my @data = @{$hash{data}};
    my $cols = scalar(@$header);

    
    my @col_props = map{ {} } (1 .. $cols );
    $col_props[$#col_props] = { justify => 'right' } ;
    $col_props[$#col_props-1] = { justify => 'right' } ;
    my $max_rows = $self->max_itemized_rows;

    my $i=0;
    while(@data){
       if( $i>0){
           $self->pdf_g->endpath();
          $self->init_page or return;
       }
       $i++;

       my @table_data = splice(@data,0,$max_rows);
       my %params = (
           x       => 50,
           w       => 495,
           start_y => 550,
           start_h => 400,
           padding => 2,
           border => 0,
           font => $self->pdf->corefont("Helvetica", -encoding => "utf8"), # default font
           font_size      => $hash{size},
           header_props => { font => $self->pdf->corefont('Helvetica-Bold', -encoding => "utf8"), bg_color   => 'white', font_color => "#000000",font_size =>$hash{size} },
           column_props => \@col_props

        );
        
        unless(@data){
            my @last_2_cells_bold = map{  [map{{ font_color => "#000000",}} (1.. $cols )] } (2 ..  (scalar(@table_data) + 1));
            $last_2_cells_bold[$#last_2_cells_bold]= [map{{ font_color => "red",}} (1.. $cols )  ];
            $params{cell_props}=\@last_2_cells_bold ;
        }

        $table->table( $self->pdf, $self->pdf_page, [$header,@table_data], %params);

        # $row_count = scalar(@table_data);
        # if($row_count <= 5){
            # my $space_val = (scalar(@table_data ) + 6 )* -18 ; # -18 experimentally derived spacing value
            # $self->pdf_text->cr($space_val);
       
        # }
    }

    return 1;
}

sub invoice_footer_config {
    my $self = shift; 
    [
        {size => 12, font_name => 'Helvetica-Bold', data =>   ['Notes' ] },
        {size => 12, font_name => 'Helvetica', data =>   [
            '* Payment cannot be credited without the MGI Invoice-NBR (' .$self->model->invoice_sequence .   ') ',
            '* Payment is due upon receipt of invoice.',
            '* Payment must be in US Dollars. Credit Cards are not accepted.',
            '* This Email is the only Invoice you will receive unless otherwise requested.'
            ],  separate_by_space => -10 },

      #  washu_contact_summary
        {size => 12, font_name => 'Helvetica-Bold', data => [ 'Contact Information'] },
        {size => 12, font_name => 'Helvetica', data => [ 'Name: Amy Reily', 'Email: akozlowi@genome.wustl.edu','Phone: 314-286-1827'], separate_by_space => -10},

      #  payment instructions
        {size => 12, font_name => 'Helvetica-Bold', data => ['Payment Instructions/Address']},
        {size => 12, font_name => 'Helvetica', data => [ "Make check payable to 'Washington University'"], separate_by_space => -10},

        {size => 12, font_name => 'Helvetica', data => [
            "\t".'Washington University in St. Louis',
            "\t".'Attn: Amy Reily',
            "\t".'The McDonnell Genome Institute, CB 8501',
            "\t".'4444 Forest Park Blvd.',
            "\t".'St. Louis, MO 63108',
            "\t".'USA',
            ''
            ],
        },
    ];
}

sub add_footer_to_pdf_page {
    my ($self, $array_ref) = @_;
        $self->init_page or return;
        $self->add_config_hash_to_pdf_page(%$_) for @$array_ref;
    return 1;
}

sub resolve_file_name {
    my $self = shift;
    my $dir = App::Path->tempdir;

    my $file_name =   $self->model->project_name . '.pdf';
    $file_name =~ s/\s+/_/g;
    return $dir . "/".$file_name;
}

sub commify {
    my ($val)= @_;
    ( my $num = $val ) =~ s/\G(\d{1,3})(?=(?:\d\d\d)+(?:\.|$))/$1,/g;
    return $num;
}

__PACKAGE__->meta->make_immutable;
1;
