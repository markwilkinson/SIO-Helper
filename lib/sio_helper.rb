require "sio_helper/version"
require 'uuidtools'
require 'rdf'
require 'rdf/turtle'

module SioHelper
  class Error < StandardError; end
  
      # triplify(meURI, "http://www.w3.org/1999/02/22-rdf-syntax-ns#type", "http://fairmetrics.org/resources/metric_evaluation_result", g );
  class SioHelper
    def triplify(s, p, o, repo)
  
        repo = RDF::Graph.new if repo.nil?
    
        if s.class == String
                s = s.strip
        end
        if p.class == String
                p = p.strip
        end
        if o.class == String
                o = o.strip
        end
        
        unless s.respond_to?('uri')
          
          if s.to_s =~ /^\w+:\/?\/?[^\s]+/
                  s = RDF::URI.new(s.to_s)
          else
            abort "Subject #{s.to_s} must be a URI-compatible thingy"
          end
        end
        
        unless p.respond_to?('uri')
        
          if p.to_s =~ /^\w+:\/?\/?[^\s]+/
                  p = RDF::URI.new(p.to_s)
          else
            abort "Predicate #{p.to_s} must be a URI-compatible thingy"
          end
        end
       

        unless o.respond_to?('uri')
          if o.to_s =~ /^\w+:\/?\/?[^\s]+/
                  o = RDF::URI.new(o.to_s)
          elsif o.to_s =~ /^\d{4}-[01]\d-[0-3]\d/
                  o = RDF::Literal.new(o.to_s, :datatype => RDF::XSD.date)
          elsif o.to_s =~ /^[+-]?\d+\.\d+/
                  o = RDF::Literal.new(o.to_s, :datatype => RDF::XSD.float)
          elsif o.to_s =~ /^[+-]?[0-9]+$/
                  o = RDF::Literal.new(o.to_s, :datatype => RDF::XSD.int)
          elsif o.respond_to?('gsub')
                  o.gsub!(/^_+/, "")  # strip off the leading ___ which are an indication of a literal string
                  o = RDF::Literal.new(o.to_s, :language => :en)
          else
                  warn "Could not find anything to do with the object #{o}.  Giving up. Proceeding to next triple"
          end
        end
        
        triple = RDF::Statement(s, p, o) 
        repo.insert(triple)
        
        return repo
    end


    def createSIOAttribute(attr)
        rdf =  RDF::Vocabulary.new("http://www.w3.org/1999/02/22-rdf-syntax-ns#")
        rdfs = RDF::Vocabulary.new("http://www.w3.org/2000/01/rdf-schema#")
        sio = RDF::Vocabulary.new("http://semanticscience.org/resource/")

        base = attr.fetch("base", "undefined"); base.strip!
        subjectID = attr.fetch("subjectID", "undefined"); subjectID.strip!
        subjectGUID = attr.fetch("subjectGUID", "undefined")
        processType = attr.fetch("processType", [sio.activity])
        processType = [processType] unless processType.is_a?Array  # force array

        processTypeLabel = attr.fetch("processTypeLabel", "undefined activity"); processTypeLabel.strip!  # process 
        
        attrType = attr.fetch("attrType", [sio.attribute])  # subject has-attribute attr a attributeType
        attrType = [attrType] unless attrType.is_a?Array  # force array

        attrTypeLabel = attr.fetch("attrTypeLabel", "undefined attribute"); attrTypeLabel.strip!
        
        attrValue = attr.fetch("attrValue", "undefined");
        attrValueType = attr.fetch("attrValueType", [sio["measurement-value"]])
        attrValueType = [attrValueType] unless attrValueType.is_a?Array
        
        attrValueLabel = attr.fetch("attrValueLabel", "undefined"); attrValueLabel.strip!
        attrValueUnit = attr.fetch("attrValueUnit", "undefined")
        attrValueUnitLabel = attr.fetch("attrValueUnitLabel", "undefined"); attrValueUnitLabel.strip!
        
        g = RDF::Graph.new()
        
        uuid = UUIDTools::UUID.timestamp_create.to_s
        
        
        #puts "\n\nUUID is #{uuid}\n\n"
        my = RDF::Vocabulary.new(base)   # this will be e.g. a non-container LDP Resource (not a container!)

        subjectguid = ""
        if subjectGUID != "undefined"
            subjectguid = subjectGUID   # if you send me the subject explicitly, I will use that as the subject
        elsif subjectID != "undefined"
            subjectguid = my["#subject_#{subjectID}"]  # otherwise, I create a new fragment using that Resource as base
        else
            abort "you must provide either a subject ID + base, or a subject GUID"
        end


        triplify(subjectguid, sio["has-attribute"], my["attrib_#{uuid}"], g)
        triplify(my["activity_#{uuid}"], sio["has-participant"], subjectguid, g)
        triplify(subjectguid, sio["participates-in"], my["activity_#{uuid}"] , g)
        
        triplify(my["activity_#{uuid}"], sio["has-output"], my["measurement_value_#{uuid}"], g)
        triplify(my["measurement_value_#{uuid}"], sio["is-output-of"], my["activity_#{uuid}"] , g)
        triplify(my["measurement_value_#{uuid}"], rdf.type, sio["measurement-value"], g)
        
        triplify(my["activity_#{uuid}"], rdf.type, sio.measuring, g)        
        processType.each do |pt|
          triplify(my["activity_#{uuid}"], rdf.type, pt, g)
        end
        triplify(my["activity_#{uuid}"], rdfs.label, processTypeLabel, g)      
        
        attrType.each do |at|
          triplify(my["attrib_#{uuid}"], rdf.type, at, g)
        end
        triplify(my["attrib_#{uuid}"], rdf.type, sio.attribute, g) # might be redundant
        triplify(my["attrib_#{uuid}"], rdfs.label, attrTypeLabel, g)
        
        triplify(my["attrib_#{uuid}"], sio["has-measurement-value"], my["meas_val_#{uuid}"], g)  
      
        triplify(my["meas_val_#{uuid}"], rdf.type, sio["measurement-value"], g)
        attrValueType.each do |avt|
          triplify(my["meas_val_#{uuid}"], rdf.type, avt, g)
        end
        
        triplify(my["meas_val_#{uuid}"], sio["has-value"], attrValue , g) unless attrValue == "undefined"
        triplify(my["meas_val_#{uuid}"], rdfs.label, attrValueLabel , g) unless attrValueLabel == "undefined"
        triplify(my["meas_val_#{uuid}"], sio["has-unit"] , attrValueUnit , g) unless attrValueUnit == "undefined"
        if attrValue != "undefined" and attrValueUnitLabel != "undefined"
            triplify(my["meas_val_#{uuid}"], rdfs.label, attrValue.to_s + " " + attrValueUnitLabel.to_s , g)
        elsif attrValue != "undefined" and attrValueLabel == "undefined"
            triplify(my["meas_val_#{uuid}"], rdfs.label, attrValue.to_s, g)
        end

        triplify(attrValueUnit, rdfs.label, attrValueUnitLabel , g) unless attrValueUnit == "undefined"

        return g
        
    end
    
  end
    
    
  class General
    def self.setNamespaces()
      $rdf =  RDF::Vocabulary.new("http://www.w3.org/1999/02/22-rdf-syntax-ns#")
      $rdfs = RDF::Vocabulary.new("http://www.w3.org/2000/01/rdf-schema#")
      $ldp = RDF::Vocabulary.new("http://www.w3.org/ns/ldp#")
      $sio = RDF::Vocabulary.new("http://semanticscience.org/resource/")
      $uo =  RDF::Vocabulary.new("http://purl.obolibrary.org/obo/uo.owl#")
      $efo = RDF::Vocabulary.new("http://www.ebi.ac.uk/efo/efo.owl#")
      $taxon = RDF::Vocabulary.new("http://purl.obolibrary.org/obo/NCBITaxon_")
      $rel = RDF::Vocabulary.new("http://purl.obolibrary.org/obo/RO_")
      $obi = RDF::Vocabulary.new("http://purl.obolibrary.org/obo/OBI_")
      $ero = RDF::Vocabulary.new("http://purl.obolibrary.org/obo/ERO_")
      $rdc = RDF::Vocabulary.new("http://rdf.biosemantics.org/ontologies/rd-connect/rdc-meta/")
      $ncit = RDF::Vocabulary.new("http://purl.obolibrary.org/obo/NCIT_")
      $ordo =  RDF::Vocabulary.new("http://www.orpha.net/ORDO/")
      $dbsnp = RDF::Vocabulary.new("https://www.ncbi.nlm.nih.gov/snp/")
      $dcat = RDF::Vocabulary.new("http://www.w3.org/ns/dcat#")
      $skos = RDF::Vocabulary.new("http://www.w3.org/2004/02/skos/core#")
      $dct = RDF::Vocabulary.new("http://purl.org/dc/terms/")
      $schema = RDF::Vocabulary.new("http://schema.org/")
      $foaf = RDF::Vocabulary.new("http://xmlns.com/foaf/0.1/")
    end
  
  end
  
end
