require 'yaml'
require 'json'
require_relative '../utilities/inspec_util'
require_relative '../utilities/csv_util'

# rubocop:disable Style/GuardClause

module InspecTools
  class CLI < Command
    desc 'xccdf2inspec', 'xccdf2inspec translates an xccdf file to an inspec profile'
    long_desc Help.text(:xccdf2inspec)
    option :xccdf, required: true, aliases: '-x'
    option :attributes, required: false, aliases: '-a'
    option :output, required: false, aliases: '-o', default: 'profile'
    option :format, required: false, aliases: '-f', enum: %w{ruby hash}, default: 'ruby'
    option :separate_files, required: false, type: :boolean, default: true, aliases: '-s'
    option :replace_tags, required: false, aliases: '-r'
    option :metadata, required: false, aliases: '-m'
    def xccdf2inspec
      xccdf = XCCDF.new(File.read(options[:xccdf]), options[:replace_tags])
      profile = xccdf.to_inspec

      if !options[:metadata].nil?
        xccdf.inject_metadata(File.read(options[:metadata]))
      end

      Utils::InspecUtil.unpack_inspec_json(options[:output], profile, options[:separate_files], options[:format])
      if !options[:attributes].nil?
        attributes = xccdf.to_attributes
        File.write(options[:attributes], YAML.dump(attributes))
      end
    end

    desc 'inspec2xccdf', 'inspec2xccdf translates an inspec profile and attributes files to an xccdf file'
    long_desc Help.text(:inspec2xccdf)
    option :inspec_json, required: true, aliases: '-j'
    option :attributes,  required: true, aliases: '-a'
    option :output, required: true, aliases: '-o'
    def inspec2xccdf
      json = File.read(options[:inspec_json])
      inspec_tool = InspecTools::Inspec.new(json)
      attr_hsh = YAML.load_file(options[:attributes])
      xccdf = inspec_tool.to_xccdf(attr_hsh)
      File.write(options[:output], xccdf)
    end

    desc 'csv2inspec', 'csv2inspec translates CSV to Inspec controls using a mapping file'
    long_desc Help.text(:csv2inspec)
    option :csv, required: true, aliases: '-c'
    option :mapping, required: true, aliases: '-m'
    option :verbose, required: false, type: :boolean, aliases: '-V'
    option :output, required: false, aliases: '-o', default: 'profile'
    option :format, required: false, aliases: '-f', enum: %w{ruby hash}, default: 'ruby'
    option :separate_files, required: false, type: :boolean, default: true, aliases: '-s'
    def csv2inspec
      csv = CSV.read(options[:csv], encoding: 'ISO8859-1')
      mapping = YAML.load_file(options[:mapping])
      profile = CSVTool.new(csv, mapping, options[:csv].split('/')[-1].split('.')[0], options[:verbose]).to_inspec
      Utils::InspecUtil.unpack_inspec_json(options[:output], profile, options[:separate_files], options[:format])
    end

    desc 'inspec2csv', 'inspec2csv translates Inspec controls to CSV'
    long_desc Help.text(:inspec2csv)
    option :inspec_json, required: true, aliases: '-j'
    option :output, required: true, aliases: '-o'
    option :verbose, required: false, type: :boolean, aliases: '-V'
    def inspec2csv
      csv = Inspec.new(File.read(options[:inspec_json])).to_csv
      Utils::CSVUtil.unpack_csv(csv, options[:output])
    end

    desc 'inspec2ckl', 'inspec2ckl translates an inspec json file to a Checklist file'
    long_desc Help.text(:inspec2ckl)
    option :inspec_json, required: true, aliases: '-j'
    option :output, required: true, aliases: '-o'
    option :verbose, type: :boolean, aliases: '-V'
    option :metadata, required: false, aliases: '-m'
    def inspec2ckl
      metadata = '{}'
      if !options[:metadata].nil?
        metadata = File.read(options[:metadata])
      end
      ckl = InspecTools::Inspec.new(File.read(options[:inspec_json]), metadata).to_ckl
      File.write(options[:output], ckl)
    end

    desc 'pdf2inspec', 'pdf2inspec translates a PDF Security Control Speficication to Inspec Security Profile'
    long_desc Help.text(:pdf2inspec)
    option :pdf, required: true, aliases: '-p'
    option :output, required: false, aliases: '-o', default: 'profile'
    option :debug, required: false, aliases: '-d', type: :boolean, default: false
    option :format, required: false, aliases: '-f', enum: %w{ruby hash}, default: 'ruby'
    option :separate_files, required: false, type: :boolean, default: true, aliases: '-s'
    def pdf2inspec
      pdf = File.open(options[:pdf])
      profile = InspecTools::PDF.new(pdf, options[:output], options[:debug]).to_inspec
      Utils::InspecUtil.unpack_inspec_json(options[:output], profile, options[:separate_files], options[:format])
    end

    desc 'generate_map', 'Generates mapping template from CSV to Inspec Controls'
    def generate_map
      template = '
      # Setting csv_header to true will skip the csv file header
      skip_csv_header: true
      width   : 80


      control.id: 0
      control.title: 15
      control.desc: 16
      control.tags:
              severity: 1
              rid: 8
              stig_id: 3
              cci: 2
              check: 12
              fix: 10
      '
      myfile = File.new('mapping.yml', 'w')
      myfile.puts template
      myfile.close
    end

    desc 'generate_ckl_metadata', 'Generate metadata file that can be passed to inspec2ckl'
    def generate_ckl_metadata
      metadata = {}

      metadata['stigid'] = ask('STID ID: ')
      metadata['role'] = ask('Role: ')
      metadata['type'] = ask('Type: ')
      metadata['hostname'] = ask('Hostname: ')
      metadata['ip'] = ask('IP Address: ')
      metadata['mac'] = ask('MAC Address: ')
      metadata['fqdn'] = ask('FQDN: ')
      metadata['tech_area'] = ask('Tech Area: ')
      metadata['target_key'] = ask('Target Key: ')
      metadata['web_or_database'] = ask('Web or Database: ')
      metadata['web_db_site'] = ask('Web DB Site: ')
      metadata['web_db_instance'] = ask('Web DB Instance: ')

      metadata.delete_if { |_key, value| value.empty? }
      File.open('metadata.json', 'w') do |f|
        f.write(metadata.to_json)
      end
    end

    desc 'generate_inspec_metadata', 'Generate mapping file that can be passed to xccdf2inspec'
    def generate_inspec_metadata
      metadata = {}

      metadata['maintainer'] = ask('Maintainer: ')
      metadata['copyright'] = ask('Copyright: ')
      metadata['copyright_email'] = ask('Copyright Email: ')
      metadata['license'] = ask('License: ')
      metadata['version'] = ask('Version: ')

      metadata.delete_if { |_key, value| value.empty? }
      File.open('metadata.json', 'w') do |f|
        f.write(metadata.to_json)
      end
    end

    desc 'summary', 'summary parses an inspec results json to create a summary json'
    long_desc Help.text(:summary)
    option :inspec_json, required: true, aliases: '-j'
    option :output, required: true, aliases: '-o'
    option :verbose, type: :boolean, aliases: '-V'

    def summary
      summary = InspecTools::Summary.new(File.read(options[:inspec_json])).to_summary
      File.write(options[:output], summary.to_json)
    end

    desc 'compliance', 'compliance parses an inspec results json to check if the compliance level meets a specified threshold'
    long_desc Help.text(:compliance)
    option :inspec_json, required: true, aliases: '-j'
    option :threshold_file, required: false, aliases: '-f'
    option :threshold_inline, required: false, aliases: '-i'
    option :verbose, type: :boolean, aliases: '-V'

    def compliance
      if options[:threshold_file].nil? && options[:threshold_inline].nil?
        puts 'Please provide threshold as a yaml file or inline yaml'
        exit(1)
      end
      threshold = YAML.load_file(options[:threshold_file]) unless options[:threshold_file].nil?
      threshold = YAML.safe_load(options[:threshold_inline]) unless options[:threshold_inline].nil?
      compliance = InspecTools::Summary.new(File.read(options[:inspec_json])).threshold(threshold)
      compliance ? exit(0) : exit(1)
    end

    desc 'version', 'prints version'
    def version
      puts VERSION
    end
  end
end
