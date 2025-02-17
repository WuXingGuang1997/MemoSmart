import SwiftUI
import AVFoundation

// MARK: - Estensione per nascondere la tastiera
final class AudioPlayerDelegate: NSObject, AVAudioPlayerDelegate {
    var onFinish: (() -> Void)?
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onFinish?()
    }
}

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
    }
}

// MARK: - Modello Nota
struct Note: Identifiable, Codable {
    let id: UUID
    var title: String
    var content: String
    var category: String
    var imageData: Data?
    var audioFileName: String?
    
    var image: UIImage? {
        get { imageData.flatMap { UIImage(data: $0) } }
        set { imageData = newValue?.pngData() }
    }
    
    var audioURL: URL? {
        guard let fileName = audioFileName else { return nil }
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent(fileName)
    }
}

// MARK: - ViewModel per la persistenza delle note
class NotesViewModel: ObservableObject {
    @Published var notes: [Note] = [] {
        didSet { saveNotes() }
    }
    
    private let savePath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("notes.json")
    
    init() {
        loadNotes()
    }
    
    func add(note: Note) {
        notes.append(note)
    }
    
    func delete(at offsets: IndexSet) {
        notes.remove(atOffsets: offsets)
    }
    
    private func saveNotes() {
        do {
            let data = try JSONEncoder().encode(notes)
            try data.write(to: savePath, options: [.atomicWrite, .completeFileProtection])
        } catch {
            print("Errore nel salvataggio delle note: \(error.localizedDescription)")
        }
    }
    
    private func loadNotes() {
        do {
            let data = try Data(contentsOf: savePath)
            notes = try JSONDecoder().decode([Note].self, from: data)
        } catch {
            print("Nessuna nota salvata o errore nel caricamento: \(error.localizedDescription)")
        }
    }
}

// MARK: - ContentView: Lista delle note con grafica migliorata
struct ContentView: View {
    @StateObject private var viewModel = NotesViewModel()
    @State private var showingNewNote = false
    @State private var searchText: String = ""
    
    // Computed property per filtrare le note in base a titolo, categoria e contenuto
    var filteredNotes: [Note] {
        if searchText.isEmpty {
            return viewModel.notes
        } else {
            return viewModel.notes.filter { note in
                note.title.lowercased().contains(searchText.lowercased()) ||
                note.category.lowercased().contains(searchText.lowercased()) ||
                note.content.lowercased().contains(searchText.lowercased())
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Sfondo a gradiente
                LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.2)]),
                               startPoint: .topLeading,
                               endPoint: .bottomTrailing)
                    .ignoresSafeArea()
                    .onTapGesture { self.hideKeyboard() }
                
                List {
                    ForEach(filteredNotes) { note in
                        NavigationLink(destination: NoteDetailView(note: note)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(note.title)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text(note.category)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white)
                                    .shadow(color: Color.black.opacity(0.15), radius: 5, x: 0, y: 3)
                            )
                        }
                        .listRowBackground(Color.clear)
                    }
                    .onDelete(perform: viewModel.delete)
                }
                .listStyle(PlainListStyle())
                .padding(.vertical)
                // Aggiungiamo il campo di ricerca
                .searchable(text: $searchText, prompt: "Cerca titolo, categoria o contenuto")
            }
            .navigationTitle("MemoSmart")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingNewNote = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                }
            }
            .sheet(isPresented: $showingNewNote) {
                NewNoteView(viewModel: viewModel)
            }
        }
    }
}

// MARK: - Dettaglio Nota con audio affidabile e volume aumentato

struct NoteDetailView: View {
    var note: Note
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPlaying = false
    @State private var audioDelegate = AudioPlayerDelegate()
    
    var body: some View {
        ZStack {
            // Sfondo a gradiente per l'intero schermo
            LinearGradient(gradient: Gradient(colors: [Color.orange.opacity(0.2), Color.red.opacity(0.2)]),
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Sezione contenuto: titolo, categoria, immagine e descrizione
                    VStack(alignment: .leading, spacing: 8) {
                        Text(note.title)
                            .font(.largeTitle)
                            .bold()
                            .padding(.top)
                        
                        Text("Categoria: \(note.category)")
                            .font(.title3)
                            .foregroundColor(.secondary)
                        
                        if let image = note.image {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .cornerRadius(10)
                                .shadow(radius: 5)
                        }
                        
                        Text(note.content)
                            .font(.body)
                            .padding(.vertical)
                    }
                    
                    // Divider per separare il contenuto dalla sezione audio
                    Divider()
                        .padding(.vertical)
                    
                    // Sezione audio: pulsante dedicato
                    if let audioURL = note.audioURL {
                        Button(action: {
                            if isPlaying {
                                stopAudio()
                            } else {
                                playAudio(from: audioURL)
                            }
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                                    .font(.title)
                                Text(isPlaying ? "Ferma Audio" : "Riproduci Audio")
                                    .font(.headline)
                            }
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                    
                    Spacer()
                }
                .padding()
                .onTapGesture { self.hideKeyboard() }
            }
        }
        .navigationTitle("Dettaglio Nota")
    }
    
    private func playAudio(from url: URL) {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.volume = 8.0  // Volume al massimo
            audioPlayer?.prepareToPlay()
            // Imposta il delegato per rilevare quando l'audio termina
            audioDelegate.onFinish = {
                self.isPlaying = false
            }
            audioPlayer?.delegate = audioDelegate
            audioPlayer?.play()
            isPlaying = true
        } catch {
            print("Errore nella riproduzione audio: \(error.localizedDescription)")
        }
    }
    
    private func stopAudio() {
        audioPlayer?.stop()
        isPlaying = false
    }
}

// Classe delegata per gestire il termine della riproduzione audio


// MARK: - Vista per creare una nuova nota con registrazione audio e grafica migliorata
struct NewNoteView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var viewModel: NotesViewModel
    
    @State private var title: String = ""
    @State private var content: String = ""
    @State private var category: String = ""
    
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    
    // Variabili per la registrazione audio
    @State private var isRecording = false
    @State private var recorder: AVAudioRecorder?
    @State private var audioFileName: String?
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                    .onTapGesture { self.hideKeyboard() }
                
                Form {
                    Section(header: Text("Dettagli Nota").font(.headline)) {
                        TextField("Titolo", text: $title)
                        TextField("Categoria", text: $category)
                        TextEditor(text: $content)
                            .frame(height: 150)
                    }
                    
                    Section(header: Text("Immagine").font(.headline)) {
                        if let image = selectedImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 150)
                                .clipped()
                                .cornerRadius(10)
                        }
                        Button(action: { showImagePicker = true }) {
                            Text(selectedImage == nil ? "Aggiungi Immagine" : "Cambia Immagine")
                        }
                    }
                    
                    Section(header: Text("Audio").font(.headline)) {
                        if let fileName = audioFileName {
                            Text("Audio registrato: \(fileName)")
                        }
                        Button(action: { toggleRecording() }) {
                            HStack(spacing: 8) {
                                Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                                    .font(.title2)
                                Text(isRecording ? "Ferma Registrazione" : "Registra Audio")
                            }
                        }
                    }
                }
                .animation(.easeInOut, value: isRecording)
            }
            .navigationTitle("Nuova Nota")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Annulla") { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Salva") {
                        let newNote = Note(id: UUID(),
                                           title: title,
                                           content: content,
                                           category: category,
                                           imageData: selectedImage?.pngData(),
                                           audioFileName: audioFileName)
                        viewModel.add(note: newNote)
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(selectedImage: $selectedImage)
            }
            .onAppear {
                // Richiediamo il permesso per l'uso del microfono
                AVAudioSession.sharedInstance().requestRecordPermission { allowed in
                    if !allowed { print("Accesso al microfono negato") }
                }
            }
        }
    }
    
    // MARK: - Funzione per gestire la registrazione audio
    private func toggleRecording() {
        if isRecording {
            recorder?.stop()
            recorder = nil
            isRecording = false
        } else {
            let audioSession = AVAudioSession.sharedInstance()
            do {
                try audioSession.setCategory(.playAndRecord, mode: .default)
                try audioSession.setActive(true)
                
                let fileName = UUID().uuidString + ".m4a"
                audioFileName = fileName
                let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent(fileName)
                
                let settings: [String: Any] = [
                    AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                    AVSampleRateKey: 12000,
                    AVNumberOfChannelsKey: 1,
                    AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
                ]
                
                recorder = try AVAudioRecorder(url: fileURL, settings: settings)
                recorder?.record()
                isRecording = true
            } catch {
                print("Errore nella registrazione audio: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - ImagePicker per selezionare un'immagine dalla libreria
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.presentationMode) private var presentationMode
    
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        init(parent: ImagePicker) { self.parent = parent }
        
        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
    
    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
}


