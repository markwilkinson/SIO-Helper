require 'uuidtools'
require 'rdf'
require 'rdf/turtle'


class SioHelper

    # triplify(meURI, "http://www.w3.org/1999/02/22-rdf-syntax-ns#type", "http://fairmetrics.org/resources/metric_evaluation_result", g );

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
          else
                  o = RDF::Literal.new(o.to_s, :language => :en)
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

        base = attr.fetch("base", "undefined")
        subjectID = attr.fetch("subjectID", "undefined")
        subjectGUID = attr.fetch("subjectGUID", "undefined")
        processType = attr.fetch("processType", "undefined")  # process involves subject
        processTypeLabel = attr.fetch("processTypeLabel", "undefined activity")  # process 
        
        attrType = attr.fetch("attrType", "undefined")  # subject has-attribute attr a attributeType
        attrTypeLabel = attr.fetch("attrTypeLabel", "undefined attribute")
        
        attrValue = attr.fetch("attrValue", "undefined")
        attrValueUnit = attr.fetch("attrValueUnit", "undefined")
        attrValueUnitLabel = attr.fetch("attrValueUnitLabel", "undefined")
        
        g = RDF::Graph.new()
        
        uuid = UUIDTools::UUID.timestamp_create.to_s
        
        my = RDF::Vocabulary.new(base)

        subjectguid = ""
        if subjectGUID != "undefined"
            subjectguid = subjectGUID
        elsif subjectID != "undefined"
            subjectguid = my["#subject_#{subjectID}"]
        else
            abort "you must provide either a subject ID or a subject GUID"
        end


        triplify(subjectguid, sio["has-attribute"], my["attrib_#{uuid}"], g)
        triplify(my["activity_#{uuid}"], sio["has-participant"], subjectguid, g)
        
        triplify(my["activity_#{uuid}"], sio["has-output"], my["measurement_value_#{uuid}"], g)
        triplify(my["measurement_value_#{uuid}"], rdf.type, sio["measurement-value"], g)
        
        triplify(my["activity_#{uuid}"], rdf.type, sio.measuring, g)
        triplify(my["activity_#{uuid}"], rdf.type, processType, g) unless processType == "undefined"
        triplify(processType, rdfs.label, processTypeLabel , g) unless processType == "undefined"
        triplify(my["activity_#{uuid}"], rdfs.label, processTypeLabel, g)      
        
        triplify(my["attrib_#{uuid}"], rdf.type, sio.attribute, g)
        triplify(my["attrib_#{uuid}"], rdf.type, attrType, g) unless attrType == "undefined"
        triplify(attrType, rdfs.label, attrTypeLabel, g) unless attrType == "undefined"
        triplify(my["attrib_#{uuid}"], rdfs.label, attrTypeLabel, g)
        
        triplify(my["attrib_#{uuid}"], sio["has-measurement-value"], my["meas_val_#{uuid}"], g)  
      
        triplify(my["meas_val_#{uuid}"], rdf.type, sio["measurement-value"], g)
        triplify(my["meas_val_#{uuid}"], sio["has-value"], attrValue , g) unless attrValue == "undefined"
        triplify(my["meas_val_#{uuid}"], sio["has-unit"] , attrValueUnit , g) unless attrValueUnit == "undefined"
        if attrValue != "undefined" and attrValueUnitLabel != "undefined"
            triplify(my["meas_val_#{uuid}"], rdfs.label, attrValue.to_s + " " + attrValueUnitLabel.to_s , g)
        elsif attrValue != "undefined"
            triplify(my["meas_val_#{uuid}"], rdfs.label, attrValue.to_s, g)
        end

        triplify(attrValueUnit, rdfs.label, attrValueUnitLabel , g) unless attrValueUnit == "undefined"

        return g
        
    end
        
        
end
      