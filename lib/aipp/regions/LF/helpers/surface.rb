module AIPP
  module LF
    module Helpers
      module Surface

        # Map surface to OFMX composition, preparation and remarks
        SURFACES = {
          /^revêtue?$/ => { preparation: :paved },
          /^non revêtue?$/ => { preparation: :natural },
          'macadam' => { composition: :macadam },
          /^bitume ?(traité|psp)?$/ =>  { composition: :bitumen },
          'ciment' => { composition: :concrete, preparation: :paved },
          /^b[eéè]ton ?(armé|bitume|bitumeux|bitumineux)?$/ => { composition: :concrete, preparation: :paved },
          /^béton( de)? ciment$/ => { composition: :concrete, preparation: :paved },
          'béton herbe' => { composition: :concrete_and_grass },
          'béton avec résine' => { composition: :concrete, preparation: :paved, remarks: 'Avec résine / with resin' },
          "béton + asphalte d'étanchéité sablé" => { composition: :concrete_and_asphalt, preparation: :paved, remarks: 'Étanchéité sablé / sandblasted waterproofing' },
          'béton armé + support bitumastic' => { composition: :concrete, preparation: :paved, remarks: 'Support bitumastic / bitumen support' },
          /résine (époxy )?su[er] béton/ => { composition: :concrete, preparation: :paved, remarks: 'Avec couche résine / with resin seal coat' },
          /^(asphalte|tarmac)$/ => { composition: :asphalt, preparation: :paved },
          'enrobé' => { preparation: :other, remarks: 'Enrobé / coated' },
          'enrobé anti-kérozène' => { preparation: :other, remarks: 'Enrobé anti-kérozène / anti-kerosene coating' },
          /^enrobé bitum(e|iné|ineux)$/ => { composition: :bitumen, preparation: :paved, remarks: 'Enrobé / coated' },
          'enrobé béton' => { composition: :concrete, preparation: :paved, remarks: 'Enrobé / coated' },
          /^résine( époxy)?$/ => { composition: :other, remarks: 'Résine / resin' },
          'tole acier larmé' => { composition: :metal, preparation: :grooved },
          /^(structure métallique|structure et caillebotis métallique|aluminium)$/ => { composition: :metal },
          'matériaux composites ignifugés' => { composition: :other, remarks: 'Matériaux composites ignifugés / fire resistant mixed materials' },
          /^(gazon|herbe)$/ => { composition: :grass },
          'neige' => { composition: :snow },
          'neige damée' => { composition: :snow, preparation: :rolled },
          'surface en bois' => { composition: :wood }
        }.freeze

        def surface_from(node)
          AIXM.surface.tap do |surface|
            SURFACES.metch(node.(:Revetement), default: {}).tap do |surface_attributes|
              surface.composition = surface_attributes[:composition]
              surface.preparation = surface_attributes[:preparation]
              surface.remarks = surface_attributes[:remarks]
            end
            surface.pcn = node.(:Resistance)&.first_match(AIXM::PCN_RE)
          end
        end

      end
    end
  end
end
