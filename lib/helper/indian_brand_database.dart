class IndianBrandDatabase {
  IndianBrandDatabase._();

  /// Brand name (lowercase) → generic name
  static const Map<String, String> _brands = {
    // Paracetamol / Acetaminophen
    'crocin': 'Paracetamol',
    'dolo': 'Paracetamol',
    'dolo 650': 'Paracetamol 650mg',
    'dolo-650': 'Paracetamol 650mg',
    'calpol': 'Paracetamol',
    'tylenol': 'Paracetamol',
    'pyrigesic': 'Paracetamol',
    'metacin': 'Paracetamol',
    'fepanil': 'Paracetamol',
    'caldol': 'Paracetamol',
    'pacimol': 'Paracetamol',

    // Ibuprofen / NSAIDs
    'brufen': 'Ibuprofen',
    'ibugesic': 'Ibuprofen',
    'advil': 'Ibuprofen',
    'motrin': 'Ibuprofen',
    'voveran': 'Diclofenac',
    'voltaren': 'Diclofenac',
    'diclogesic': 'Diclofenac',
    'moov': 'Diclofenac (topical)',
    'volini': 'Diclofenac (topical)',
    'disprin': 'Aspirin',
    'ecosprin': 'Aspirin',

    // Combination (Paracetamol + Ibuprofen)
    'combiflam': 'Ibuprofen + Paracetamol',

    // Antibiotics
    'augmentin': 'Amoxicillin + Clavulanate',
    'mox': 'Amoxicillin',
    'amoxil': 'Amoxicillin',
    'ciprobid': 'Ciprofloxacin',
    'ciplox': 'Ciprofloxacin',
    'cifran': 'Ciprofloxacin',
    'azithral': 'Azithromycin',
    'zithromax': 'Azithromycin',
    'azax': 'Azithromycin',
    'atm': 'Azithromycin',
    'norflox': 'Norfloxacin',
    'doxycap': 'Doxycycline',
    'vibramycin': 'Doxycycline',
    'metrogyl': 'Metronidazole',
    'flagyl': 'Metronidazole',
    'clavam': 'Amoxicillin + Clavulanate',
    'taxim': 'Cefixime',
    'zifi': 'Cefixime',
    'suprax': 'Cefixime',
    'monocef': 'Ceftriaxone',
    'wysolone': 'Prednisolone',

    // Antacids / GI
    'pantop': 'Pantoprazole',
    'pan': 'Pantoprazole',
    'pan d': 'Pantoprazole + Domperidone',
    'omez': 'Omeprazole',
    'omeprazole': 'Omeprazole',
    'razo': 'Rabeprazole',
    'rablet': 'Rabeprazole',
    'ranitac': 'Ranitidine',
    'zantac': 'Ranitidine',
    'gelusil': 'Aluminium Hydroxide + Magnesium Hydroxide',
    'digene': 'Aluminium Hydroxide + Magnesium Hydroxide',
    'eno': 'Sodium Bicarbonate (antacid)',
    'pudin hara': 'Mint + Ginger (herbal antacid)',
    'nexpro': 'Esomeprazole',
    'nexium': 'Esomeprazole',
    'domperidone': 'Domperidone',
    'motilium': 'Domperidone',
    'emeset': 'Ondansetron',
    'ondem': 'Ondansetron',

    // Diabetes
    'glycomet': 'Metformin',
    'glucophage': 'Metformin',
    'glucobay': 'Acarbose',
    'januvia': 'Sitagliptin',
    'tradjenta': 'Linagliptin',
    'glimestar': 'Glimepiride',
    'amaryl': 'Glimepiride',
    'invokana': 'Canagliflozin',
    'jardiance': 'Empagliflozin',
    'ozempic': 'Semaglutide',
    'victoza': 'Liraglutide',

    // Blood Pressure / Cardiac
    'stamlo': 'Amlodipine',
    'norvasc': 'Amlodipine',
    'amlo': 'Amlodipine',
    'telma': 'Telmisartan',
    'losar': 'Losartan',
    'cozaar': 'Losartan',
    'concor': 'Bisoprolol',
    'carvistar': 'Carvedilol',
    'metolar': 'Metoprolol',
    'lopressor': 'Metoprolol',
    'atenolol': 'Atenolol',
    'tenormin': 'Atenolol',
    'envas': 'Enalapril',
    'vasotec': 'Enalapril',
    'ramipril': 'Ramipril',
    'cardace': 'Ramipril',
    'rozavel': 'Rosuvastatin',
    'crestor': 'Rosuvastatin',
    'atorlip': 'Atorvastatin',
    'lipitor': 'Atorvastatin',
    'sorvas': 'Atorvastatin',
    'storvas': 'Atorvastatin',

    // Cholesterol
    'zocor': 'Simvastatin',
    'simvotin': 'Simvastatin',
    'ecosprin av': 'Aspirin + Atorvastatin',

    // Allergy / Antihistamines
    'allegra': 'Fexofenadine',
    'cetriz': 'Cetirizine',
    'zyrtec': 'Cetirizine',
    'montair': 'Montelukast',
    'singulair': 'Montelukast',
    'atarax': 'Hydroxyzine',
    'avil': 'Pheniramine',
    'polaramine': 'Dexchlorpheniramine',

    // Cough / Cold
    'benadryl': 'Diphenhydramine / Cough suppressant',
    'alex': 'Dextromethorphan + Chlorpheniramine',
    'corex': 'Codeine-based cough syrup',
    'phensedyl': 'Codeine-based cough syrup',
    'sinarest': 'Paracetamol + Phenylephrine + Chlorpheniramine',
    'd-cold': 'Paracetamol + Phenylephrine',
    'grilinctus': 'Terbutaline + Bromhexine',

    // Vitamins / Supplements
    'becosules': 'Vitamin B Complex + Vitamin C',
    'limcee': 'Vitamin C (Ascorbic Acid)',
    'revital': 'Multivitamin + Minerals',
    'supradyn': 'Multivitamin + Minerals',
    'shelcal': 'Calcium + Vitamin D3',
    'calcirol': 'Vitamin D3 (Cholecalciferol)',
    'tayo': 'Vitamin D3',
    'uprise': 'Vitamin D3',
    'neurobion': 'Vitamin B1, B6, B12',
    'cobadex czs': 'Vitamin B Complex + Zinc',
    'zincovit': 'Multivitamin + Zinc',

    // Thyroid
    'eltroxin': 'Levothyroxine',
    'thyronorm': 'Levothyroxine',
    'thyrox': 'Levothyroxine',

    // Neurological / Pain
    'gabapin': 'Gabapentin',
    'neurontin': 'Gabapentin',
    'lyrica': 'Pregabalin',
    'pregabalin': 'Pregabalin',
    'vertin': 'Betahistine',
    'serc': 'Betahistine',

    // Mental Health
    'nexito': 'Escitalopram',
    'serta': 'Sertraline',
    'zoloft': 'Sertraline',
    'prozac': 'Fluoxetine',
    'fluoxetine': 'Fluoxetine',
    'prodep': 'Fluoxetine',
    'librium': 'Chlordiazepoxide',
    'alprazolam': 'Alprazolam',
    'alprax': 'Alprazolam',

    // Liver / Hepatology
    'udiliv': 'Ursodeoxycholic Acid (UDCA)',
    'hepamerz': 'L-Ornithine L-Aspartate',
    'silymarin': 'Silymarin (Milk Thistle)',
    'livolin': 'Phospholipids + Vitamins (liver support)',

    // Urology / ED
    'sildigra': 'Sildenafil',
    'viagra': 'Sildenafil',
    'tadacip': 'Tadalafil',
    'cialis': 'Tadalafil',
    'tadalafil': 'Tadalafil',
    'urimax': 'Tamsulosin',
    'flomax': 'Tamsulosin',

    // Contraceptives
    'i-pill': 'Levonorgestrel (emergency contraceptive)',
    'unwanted 72': 'Levonorgestrel (emergency contraceptive)',
    'mala d': 'Norethisterone + Ethinylestradiol (OCP)',
    'duoluton': 'Norgestrel + Ethinylestradiol (OCP)',

    // Dermatology
    'candid': 'Clotrimazole',
    'canesten': 'Clotrimazole',
    'nizoral': 'Ketoconazole',
    'terbinafine': 'Terbinafine',
    'lamisil': 'Terbinafine',
    'fourderm': 'Clotrimazole + Beclomethasone + Gentamicin',
    'quadriderm': 'Betamethasone + Gentamicin + Clotrimazole',
    'soframycin': 'Framycetin (topical antibiotic)',
    'betnovate': 'Betamethasone (topical steroid)',
    'elocon': 'Mometasone (topical steroid)',

    // Ophthalmology / ENT
    'tobramycin': 'Tobramycin (eye drops)',
    'tobrex': 'Tobramycin (eye drops)',
    'ciproflox': 'Ciprofloxacin (eye/ear drops)',
    'otrivin': 'Xylometazoline (nasal decongestant)',
    'nasivion': 'Oxymetazoline (nasal decongestant)',
  };

  /// Returns the generic name for a brand, or null if not found.
  static String? resolveGeneric(String input) {
    final key = input.trim().toLowerCase();
    return _brands[key];
  }

  /// Returns true if the input is a known Indian brand name.
  static bool isBrand(String input) => resolveGeneric(input) != null;

  /// Returns brand names whose key starts with or contains [query].
  static List<String> matchingBrands(String query) {
    if (query.isEmpty) return [];
    final q = query.toLowerCase();
    return _brands.keys
        .where((k) => k.contains(q))
        .map((k) => k.split(' ').map((w) => w.isNotEmpty
            ? '${w[0].toUpperCase()}${w.substring(1)}'
            : w).join(' '))
        .toList();
  }
}
