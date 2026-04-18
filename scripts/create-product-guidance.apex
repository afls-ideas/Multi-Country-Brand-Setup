// ============================================================
// Create Product Guidance (Messages + Objectives)
// ============================================================
// Creates localized ProductGuidance records for each country
// sub-brand LifeSciMarketableProduct. Messages and Objectives
// are distinguished by the Type field.
//
// Idempotent — uses Name as the unique key per product.
// ============================================================

// -----------------------------------------------------------
// 1. LOOK UP COUNTRY SUB-BRAND MARKETABLE PRODUCTS
// -----------------------------------------------------------

Map<String, Id> mktIdByCode = new Map<String, Id>();
for (LifeSciMarketableProduct mkt : [
    SELECT Id, Name, ProductCode
    FROM LifeSciMarketableProduct
    WHERE ProductCode IN (
        'CORDIM-GB', 'CORDIM-US', 'CORDIM-FR', 'CORDIM-DE', 'CORDIM-ES', 'CORDIM-IT',
        'IMMUNEXIS-GB', 'IMMUNEXIS-US', 'IMMUNEXIS-FR', 'IMMUNEXIS-DE', 'IMMUNEXIS-ES', 'IMMUNEXIS-IT'
    )
]) {
    mktIdByCode.put(mkt.ProductCode, mkt.Id);
    System.debug('Found: ' + mkt.Name + ' (' + mkt.ProductCode + ') → ' + mkt.Id);
}

if (mktIdByCode.isEmpty()) {
    System.debug('ERROR: No country sub-brand marketable products found.');
    return;
}

// -----------------------------------------------------------
// 2. DEFINE LOCALIZED MESSAGES (Type = Message)
// -----------------------------------------------------------
// Each entry: ProductCode → List of { Name, ContentText, Priority }

Map<String, List<Map<String, String>>> messages = new Map<String, List<Map<String, String>>>();

// --- CORDIM GB (English) ---
messages.put('CORDIM-GB', new List<Map<String, String>>{
    new Map<String, String>{
        'Name' => 'Cordim GB Message1',
        'ContentText' => 'Delivers rapid and sustained symptom relief, with up to 60% improvement in joint pain and swelling by Week 12.',
        'Priority' => '1'
    },
    new Map<String, String>{
        'Name' => 'Cordim GB Message2',
        'ContentText' => 'Cordim demonstrates a favourable safety profile with low rates of serious infections in the CLARITY trial.',
        'Priority' => '2'
    },
    new Map<String, String>{
        'Name' => 'Cordim GB Message3',
        'ContentText' => 'Available in convenient 5mg and 10mg pre-filled pen formulations for patient self-administration.',
        'Priority' => '3'
    }
});

// --- CORDIM US (English) ---
messages.put('CORDIM-US', new List<Map<String, String>>{
    new Map<String, String>{
        'Name' => 'Cordim US Message1',
        'ContentText' => 'Cordim delivers rapid and sustained symptom relief, with up to 60% improvement in joint pain and swelling by Week 12.',
        'Priority' => '1'
    },
    new Map<String, String>{
        'Name' => 'Cordim US Message2',
        'ContentText' => 'Demonstrates a favorable safety profile with low rates of serious infections in the CLARITY pivotal trial.',
        'Priority' => '2'
    },
    new Map<String, String>{
        'Name' => 'Cordim US Message3',
        'ContentText' => 'Now FDA-approved for moderate-to-severe rheumatoid arthritis in adults who have had an inadequate response to one or more DMARDs.',
        'Priority' => '3'
    }
});

// --- CORDIM FR (French) ---
messages.put('CORDIM-FR', new List<Map<String, String>>{
    new Map<String, String>{
        'Name' => 'Cordim FR Message1',
        'ContentText' => 'Cordim offre un soulagement rapide et durable des symptômes, avec une amélioration allant jusqu\'à 60 % des douleurs articulaires et du gonflement à la semaine 12.',
        'Priority' => '1'
    },
    new Map<String, String>{
        'Name' => 'Cordim FR Message2',
        'ContentText' => 'Cordim présente un profil de sécurité favorable avec un faible taux d\'infections graves dans l\'étude CLARITY.',
        'Priority' => '2'
    },
    new Map<String, String>{
        'Name' => 'Cordim FR Message3',
        'ContentText' => 'Disponible en stylos pré-remplis de 5 mg et 10 mg pour une auto-administration pratique par le patient.',
        'Priority' => '3'
    }
});

// --- CORDIM DE (German) ---
messages.put('CORDIM-DE', new List<Map<String, String>>{
    new Map<String, String>{
        'Name' => 'Cordim DE Message1',
        'ContentText' => 'Cordim bietet eine schnelle und anhaltende Symptomlinderung mit bis zu 60 % Verbesserung von Gelenkschmerzen und Schwellungen bis Woche 12.',
        'Priority' => '1'
    },
    new Map<String, String>{
        'Name' => 'Cordim DE Message2',
        'ContentText' => 'Cordim zeigt ein günstiges Sicherheitsprofil mit niedrigen Raten schwerer Infektionen in der CLARITY-Studie.',
        'Priority' => '2'
    },
    new Map<String, String>{
        'Name' => 'Cordim DE Message3',
        'ContentText' => 'Erhältlich als praktischer Fertigpen in 5 mg und 10 mg zur Selbstinjektion durch den Patienten.',
        'Priority' => '3'
    }
});

// --- CORDIM ES (Spanish) ---
messages.put('CORDIM-ES', new List<Map<String, String>>{
    new Map<String, String>{
        'Name' => 'Cordim ES Message1',
        'ContentText' => 'Cordim ofrece un alivio rápido y sostenido de los síntomas, con una mejora de hasta el 60 % en el dolor articular y la hinchazón en la semana 12.',
        'Priority' => '1'
    },
    new Map<String, String>{
        'Name' => 'Cordim ES Message2',
        'ContentText' => 'Cordim presenta un perfil de seguridad favorable con bajas tasas de infecciones graves en el estudio CLARITY.',
        'Priority' => '2'
    },
    new Map<String, String>{
        'Name' => 'Cordim ES Message3',
        'ContentText' => 'Disponible en plumas precargadas de 5 mg y 10 mg para la autoadministración por parte del paciente.',
        'Priority' => '3'
    }
});

// --- CORDIM IT (Italian) ---
messages.put('CORDIM-IT', new List<Map<String, String>>{
    new Map<String, String>{
        'Name' => 'Cordim IT Message1',
        'ContentText' => 'Cordim offre un sollievo rapido e duraturo dei sintomi, con un miglioramento fino al 60% del dolore articolare e del gonfiore entro la settimana 12.',
        'Priority' => '1'
    },
    new Map<String, String>{
        'Name' => 'Cordim IT Message2',
        'ContentText' => 'Cordim dimostra un profilo di sicurezza favorevole con bassi tassi di infezioni gravi nello studio CLARITY.',
        'Priority' => '2'
    },
    new Map<String, String>{
        'Name' => 'Cordim IT Message3',
        'ContentText' => 'Disponibile in penne preriempite da 5 mg e 10 mg per l\'autosomministrazione da parte del paziente.',
        'Priority' => '3'
    }
});

// --- IMMUNEXIS GB (English) ---
messages.put('IMMUNEXIS-GB', new List<Map<String, String>>{
    new Map<String, String>{
        'Name' => 'Immunexis GB Message1',
        'ContentText' => 'Immunexis achieves ACR50 response in 45% of patients at Week 24, significantly outperforming placebo in the NEXUS-RA trial.',
        'Priority' => '1'
    },
    new Map<String, String>{
        'Name' => 'Immunexis GB Message2',
        'ContentText' => 'Dual mechanism of action targeting both IL-6 and TNF-alpha pathways provides comprehensive inflammation control.',
        'Priority' => '2'
    },
    new Map<String, String>{
        'Name' => 'Immunexis GB Message3',
        'ContentText' => 'Once-monthly subcutaneous injection supports improved patient adherence compared to weekly or biweekly regimens.',
        'Priority' => '3'
    }
});

// --- IMMUNEXIS US (English) ---
messages.put('IMMUNEXIS-US', new List<Map<String, String>>{
    new Map<String, String>{
        'Name' => 'Immunexis US Message1',
        'ContentText' => 'Immunexis achieves ACR50 response in 45% of patients at Week 24, significantly outperforming placebo in the NEXUS-RA pivotal trial.',
        'Priority' => '1'
    },
    new Map<String, String>{
        'Name' => 'Immunexis US Message2',
        'ContentText' => 'Dual mechanism of action targeting both IL-6 and TNF-alpha pathways delivers comprehensive inflammation control.',
        'Priority' => '2'
    },
    new Map<String, String>{
        'Name' => 'Immunexis US Message3',
        'ContentText' => 'FDA-approved once-monthly subcutaneous injection — the only biologic in its class with monthly dosing for moderate-to-severe RA.',
        'Priority' => '3'
    }
});

// --- IMMUNEXIS FR (French) ---
messages.put('IMMUNEXIS-FR', new List<Map<String, String>>{
    new Map<String, String>{
        'Name' => 'Immunexis FR Message1',
        'ContentText' => 'Immunexis atteint une réponse ACR50 chez 45 % des patients à la semaine 24, surpassant significativement le placebo dans l\'essai NEXUS-RA.',
        'Priority' => '1'
    },
    new Map<String, String>{
        'Name' => 'Immunexis FR Message2',
        'ContentText' => 'Double mécanisme d\'action ciblant les voies IL-6 et TNF-alpha pour un contrôle complet de l\'inflammation.',
        'Priority' => '2'
    },
    new Map<String, String>{
        'Name' => 'Immunexis FR Message3',
        'ContentText' => 'Injection sous-cutanée mensuelle unique favorisant une meilleure observance par rapport aux schémas hebdomadaires ou bihebdomadaires.',
        'Priority' => '3'
    }
});

// --- IMMUNEXIS DE (German) ---
messages.put('IMMUNEXIS-DE', new List<Map<String, String>>{
    new Map<String, String>{
        'Name' => 'Immunexis DE Message1',
        'ContentText' => 'Immunexis erreicht bei 45 % der Patienten in Woche 24 ein ACR50-Ansprechen und übertrifft damit signifikant Placebo in der NEXUS-RA-Studie.',
        'Priority' => '1'
    },
    new Map<String, String>{
        'Name' => 'Immunexis DE Message2',
        'ContentText' => 'Dualer Wirkmechanismus, der sowohl den IL-6- als auch den TNF-alpha-Signalweg hemmt, für eine umfassende Entzündungskontrolle.',
        'Priority' => '2'
    },
    new Map<String, String>{
        'Name' => 'Immunexis DE Message3',
        'ContentText' => 'Einmal monatliche subkutane Injektion unterstützt eine verbesserte Therapietreue im Vergleich zu wöchentlichen oder zweiwöchentlichen Regimen.',
        'Priority' => '3'
    }
});

// --- IMMUNEXIS ES (Spanish) ---
messages.put('IMMUNEXIS-ES', new List<Map<String, String>>{
    new Map<String, String>{
        'Name' => 'Immunexis ES Message1',
        'ContentText' => 'Immunexis alcanza una respuesta ACR50 en el 45 % de los pacientes en la semana 24, superando significativamente al placebo en el ensayo NEXUS-RA.',
        'Priority' => '1'
    },
    new Map<String, String>{
        'Name' => 'Immunexis ES Message2',
        'ContentText' => 'Doble mecanismo de acción dirigido a las vías IL-6 y TNF-alfa para un control integral de la inflamación.',
        'Priority' => '2'
    },
    new Map<String, String>{
        'Name' => 'Immunexis ES Message3',
        'ContentText' => 'Inyección subcutánea mensual única que favorece una mejor adherencia frente a los regímenes semanales o quincenales.',
        'Priority' => '3'
    }
});

// --- IMMUNEXIS IT (Italian) ---
messages.put('IMMUNEXIS-IT', new List<Map<String, String>>{
    new Map<String, String>{
        'Name' => 'Immunexis IT Message1',
        'ContentText' => 'Immunexis raggiunge una risposta ACR50 nel 45% dei pazienti alla settimana 24, superando significativamente il placebo nello studio NEXUS-RA.',
        'Priority' => '1'
    },
    new Map<String, String>{
        'Name' => 'Immunexis IT Message2',
        'ContentText' => 'Doppio meccanismo d\'azione mirato alle vie IL-6 e TNF-alfa per un controllo completo dell\'infiammazione.',
        'Priority' => '2'
    },
    new Map<String, String>{
        'Name' => 'Immunexis IT Message3',
        'ContentText' => 'Iniezione sottocutanea mensile unica che favorisce una migliore aderenza rispetto ai regimi settimanali o bisettimanali.',
        'Priority' => '3'
    }
});

// -----------------------------------------------------------
// 3. DEFINE LOCALIZED OBJECTIVES (Type = Objective)
// -----------------------------------------------------------

Map<String, List<Map<String, String>>> objectives = new Map<String, List<Map<String, String>>>();

// --- CORDIM GB ---
objectives.put('CORDIM-GB', new List<Map<String, String>>{
    new Map<String, String>{
        'Name' => 'Cordim GB Objective1',
        'ContentText' => 'Position Cordim as first-line biologic for moderate-to-severe RA patients who have failed methotrexate.',
        'Priority' => '1'
    },
    new Map<String, String>{
        'Name' => 'Cordim GB Objective2',
        'ContentText' => 'Increase Cordim new-to-brand prescriptions by 15% in NICE-approved indications within Q2 2025.',
        'Priority' => '2'
    }
});

// --- CORDIM US ---
objectives.put('CORDIM-US', new List<Map<String, String>>{
    new Map<String, String>{
        'Name' => 'Cordim US Objective1',
        'ContentText' => 'Drive Cordim adoption among rheumatologists as preferred biologic for DMARD-inadequate-response patients.',
        'Priority' => '1'
    },
    new Map<String, String>{
        'Name' => 'Cordim US Objective2',
        'ContentText' => 'Achieve 20% market share in the moderate-to-severe RA segment by end of Q3 2025.',
        'Priority' => '2'
    }
});

// --- CORDIM FR ---
objectives.put('CORDIM-FR', new List<Map<String, String>>{
    new Map<String, String>{
        'Name' => 'Cordim FR Objectif1',
        'ContentText' => 'Positionner Cordim comme biothérapie de première intention pour les patients atteints de PR modérée à sévère en échec au méthotrexate.',
        'Priority' => '1'
    },
    new Map<String, String>{
        'Name' => 'Cordim FR Objectif2',
        'ContentText' => 'Augmenter les nouvelles prescriptions de Cordim de 15 % dans les indications remboursées par la HAS au cours du T2 2025.',
        'Priority' => '2'
    }
});

// --- CORDIM DE ---
objectives.put('CORDIM-DE', new List<Map<String, String>>{
    new Map<String, String>{
        'Name' => 'Cordim DE Ziel1',
        'ContentText' => 'Cordim als First-Line-Biologikum bei Patienten mit mittelschwerer bis schwerer RA nach Methotrexat-Versagen positionieren.',
        'Priority' => '1'
    },
    new Map<String, String>{
        'Name' => 'Cordim DE Ziel2',
        'ContentText' => 'Steigerung der Cordim-Neuverordnungen um 15 % in den vom G-BA zugelassenen Indikationen im 2. Quartal 2025.',
        'Priority' => '2'
    }
});

// --- CORDIM ES ---
objectives.put('CORDIM-ES', new List<Map<String, String>>{
    new Map<String, String>{
        'Name' => 'Cordim ES Objetivo1',
        'ContentText' => 'Posicionar Cordim como biológico de primera línea para pacientes con AR moderada a grave que han fallado al metotrexato.',
        'Priority' => '1'
    },
    new Map<String, String>{
        'Name' => 'Cordim ES Objetivo2',
        'ContentText' => 'Incrementar las nuevas prescripciones de Cordim en un 15 % en las indicaciones aprobadas por la AEMPS durante el T2 2025.',
        'Priority' => '2'
    }
});

// --- CORDIM IT ---
objectives.put('CORDIM-IT', new List<Map<String, String>>{
    new Map<String, String>{
        'Name' => 'Cordim IT Obiettivo1',
        'ContentText' => 'Posizionare Cordim come biologico di prima linea per i pazienti con AR da moderata a grave in fallimento al metotrexato.',
        'Priority' => '1'
    },
    new Map<String, String>{
        'Name' => 'Cordim IT Obiettivo2',
        'ContentText' => 'Aumentare le nuove prescrizioni di Cordim del 15% nelle indicazioni approvate dall\'AIFA nel Q2 2025.',
        'Priority' => '2'
    }
});

// --- IMMUNEXIS GB ---
objectives.put('IMMUNEXIS-GB', new List<Map<String, String>>{
    new Map<String, String>{
        'Name' => 'Immunexis GB Objective1',
        'ContentText' => 'Establish Immunexis as the preferred monthly biologic for RA patients requiring IL-6 pathway inhibition.',
        'Priority' => '1'
    },
    new Map<String, String>{
        'Name' => 'Immunexis GB Objective2',
        'ContentText' => 'Secure formulary inclusion across all major NHS ICB areas by end of Q2 2025.',
        'Priority' => '2'
    }
});

// --- IMMUNEXIS US ---
objectives.put('IMMUNEXIS-US', new List<Map<String, String>>{
    new Map<String, String>{
        'Name' => 'Immunexis US Objective1',
        'ContentText' => 'Establish Immunexis as the preferred once-monthly biologic for RA patients requiring dual IL-6/TNF-alpha inhibition.',
        'Priority' => '1'
    },
    new Map<String, String>{
        'Name' => 'Immunexis US Objective2',
        'ContentText' => 'Achieve Tier 2 formulary placement with top 5 US commercial payers by end of Q3 2025.',
        'Priority' => '2'
    }
});

// --- IMMUNEXIS FR ---
objectives.put('IMMUNEXIS-FR', new List<Map<String, String>>{
    new Map<String, String>{
        'Name' => 'Immunexis FR Objectif1',
        'ContentText' => 'Établir Immunexis comme biothérapie mensuelle de référence pour les patients PR nécessitant une inhibition de la voie IL-6.',
        'Priority' => '1'
    },
    new Map<String, String>{
        'Name' => 'Immunexis FR Objectif2',
        'ContentText' => 'Obtenir l\'inscription au remboursement par la HAS dans l\'indication PR modérée à sévère d\'ici fin T2 2025.',
        'Priority' => '2'
    }
});

// --- IMMUNEXIS DE ---
objectives.put('IMMUNEXIS-DE', new List<Map<String, String>>{
    new Map<String, String>{
        'Name' => 'Immunexis DE Ziel1',
        'ContentText' => 'Immunexis als bevorzugtes monatliches Biologikum für RA-Patienten mit Bedarf an IL-6-Signalweg-Hemmung etablieren.',
        'Priority' => '1'
    },
    new Map<String, String>{
        'Name' => 'Immunexis DE Ziel2',
        'ContentText' => 'Aufnahme in die Empfehlungen der DGRh-Leitlinie für mittelschwere bis schwere RA bis Ende Q2 2025 sicherstellen.',
        'Priority' => '2'
    }
});

// --- IMMUNEXIS ES ---
objectives.put('IMMUNEXIS-ES', new List<Map<String, String>>{
    new Map<String, String>{
        'Name' => 'Immunexis ES Objetivo1',
        'ContentText' => 'Posicionar Immunexis como biológico mensual de referencia para pacientes con AR que requieren inhibición de la vía IL-6.',
        'Priority' => '1'
    },
    new Map<String, String>{
        'Name' => 'Immunexis ES Objetivo2',
        'ContentText' => 'Lograr la inclusión en el protocolo farmacoterapéutico de los 10 principales hospitales españoles antes del final del T2 2025.',
        'Priority' => '2'
    }
});

// --- IMMUNEXIS IT ---
objectives.put('IMMUNEXIS-IT', new List<Map<String, String>>{
    new Map<String, String>{
        'Name' => 'Immunexis IT Obiettivo1',
        'ContentText' => 'Affermare Immunexis come biologico mensile di riferimento per i pazienti con AR che necessitano di inibizione della via IL-6.',
        'Priority' => '1'
    },
    new Map<String, String>{
        'Name' => 'Immunexis IT Obiettivo2',
        'ContentText' => 'Ottenere l\'inserimento nel prontuario terapeutico dei principali ospedali italiani entro la fine del Q2 2025.',
        'Priority' => '2'
    }
});

// -----------------------------------------------------------
// 4. QUERY EXISTING GUIDANCE FOR IDEMPOTENCY
// -----------------------------------------------------------

Set<String> existingNames = new Set<String>();
for (ProductGuidance pg : [
    SELECT Name FROM ProductGuidance
    WHERE Name LIKE 'Cordim%' OR Name LIKE 'Immunexis%'
]) {
    existingNames.add(pg.Name);
}
System.debug('Found ' + existingNames.size() + ' existing guidance records.');

// -----------------------------------------------------------
// 5. CREATE RECORDS
// -----------------------------------------------------------

List<ProductGuidance> toInsert = new List<ProductGuidance>();
Date startDate = Date.newInstance(2025, 1, 1);
Date endDate = Date.newInstance(2028, 12, 31);

// Messages
for (String code : messages.keySet()) {
    Id mktId = mktIdByCode.get(code);
    if (mktId == null) {
        System.debug('SKIP messages for ' + code + ' — no marketable product found.');
        continue;
    }
    for (Map<String, String> msg : messages.get(code)) {
        if (existingNames.contains(msg.get('Name'))) {
            System.debug('SKIP (exists): ' + msg.get('Name'));
            continue;
        }
        toInsert.add(new ProductGuidance(
            Name = msg.get('Name'),
            ContentText = msg.get('ContentText'),
            Type = 'Message',
            Priority = Integer.valueOf(msg.get('Priority')),
            ProductReferenceRecordId = mktId,
            EffectiveStartDate = startDate,
            EffectiveEndDate = endDate,
            IsActive = true
        ));
    }
}

// Objectives
for (String code : objectives.keySet()) {
    Id mktId = mktIdByCode.get(code);
    if (mktId == null) {
        System.debug('SKIP objectives for ' + code + ' — no marketable product found.');
        continue;
    }
    for (Map<String, String> obj : objectives.get(code)) {
        if (existingNames.contains(obj.get('Name'))) {
            System.debug('SKIP (exists): ' + obj.get('Name'));
            continue;
        }
        toInsert.add(new ProductGuidance(
            Name = obj.get('Name'),
            ContentText = obj.get('ContentText'),
            Type = 'Objective',
            Priority = Integer.valueOf(obj.get('Priority')),
            ProductReferenceRecordId = mktId,
            EffectiveStartDate = startDate,
            EffectiveEndDate = endDate,
            IsActive = true
        ));
    }
}

if (!toInsert.isEmpty()) {
    insert toInsert;
    System.debug('Inserted ' + toInsert.size() + ' ProductGuidance records.');
} else {
    System.debug('All records already exist. Nothing to insert.');
}

// -----------------------------------------------------------
// 6. SUMMARY
// -----------------------------------------------------------

Integer msgCount = 0;
Integer objCount = 0;
for (ProductGuidance pg : toInsert) {
    if (pg.Type == 'Message') msgCount++;
    if (pg.Type == 'Objective') objCount++;
}

System.debug('============================================');
System.debug('PRODUCT GUIDANCE RECORDS');
System.debug('  Messages:   ' + msgCount);
System.debug('  Objectives: ' + objCount);
System.debug('  Total:      ' + toInsert.size());
System.debug('============================================');
for (ProductGuidance pg : toInsert) {
    System.debug('  [' + pg.Type + '] ' + pg.Name + ' → Priority: ' + pg.Priority);
}
