import SwiftUI
import Combine

@main
struct MySchoolApp: App {
    @StateObject private var dataManager = SchoolDataManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dataManager)
        }
    }
}

struct TodoItem: Identifiable, Codable {
    var id = UUID()
    var name: String
    var isCompleted: Bool = false
}

struct ClassItem: Identifiable, Codable {
    var id = UUID()
    var name: String
    var period: Int
    var items: [TodoItem] = []
}

struct TimeTableData: Codable {
    var mon: [ClassItem] = []
    var tue: [ClassItem] = []
    var wed: [ClassItem] = []
    var thu: [ClassItem] = []
    var fri: [ClassItem] = []
    
    subscript(day: String) -> [ClassItem] {
        get {
            switch day {
            case "월": return mon
            case "화": return tue
            case "수": return wed
            case "목": return thu
            case "금": return fri
            default: return []
            }
        }
        set {
            switch day {
            case "월": mon = newValue
            case "화": tue = newValue
            case "수": wed = newValue
            case "목": thu = newValue
            case "금": fri = newValue
            default: break
            }
        }
    }
}

struct ScheduleItem: Identifiable, Codable {
    var id = UUID()
    var name: String
    var date: Date
}

class SchoolDataManager: ObservableObject {
    @Published var timeTable = TimeTableData() {
        didSet { saveData() }
    }
    @Published var schedules: [ScheduleItem] = [] {
        didSet { saveData() }
    }
    
    private let timeTableFileName = "timetable.json"
    private let scheduleFileName = "schedule_dday.json"
    
    init() {
        loadData()
    }
    
    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private func fileURL(for fileName: String) -> URL {
        documentsDirectory.appendingPathComponent(fileName)
    }
    
    private func saveData() {
        let encoder = JSONEncoder()
        try? encoder.encode(timeTable).write(to: fileURL(for: timeTableFileName))
        try? encoder.encode(schedules).write(to: fileURL(for: scheduleFileName))
    }
    
    private func loadData() {
        let decoder = JSONDecoder()
        if let data = try? Data(contentsOf: fileURL(for: timeTableFileName)),
           let decoded = try? decoder.decode(TimeTableData.self, from: data) {
            timeTable = decoded
        }
        if let data = try? Data(contentsOf: fileURL(for: scheduleFileName)),
           let decoded = try? decoder.decode([ScheduleItem].self, from: data) {
            schedules = decoded
        }
    }
}

struct ContentView: View {
    var body: some View {
        TabView {
            TimeTableView()
                .tabItem {
                    Label("시간표", systemImage: "calendar")
                }
            
            DDayView()
                .tabItem {
                    Label("D-day", systemImage: "clock")
                }
        }
    }
}

struct TimeTableView: View {
    @EnvironmentObject var manager: SchoolDataManager
    @State private var selectedDay: String = "월"
    @State private var isEditingMode = false
    
    @State private var newClassName: String = ""
    @State private var newClassPeriod: Int = 1
    
    @State private var isShowingEditAlert = false
    @State private var editingClassID: UUID?
    @State private var editingClassName: String = ""
    @State private var editingClassPeriod: String = ""
    
    let days = ["월", "화", "수", "목", "금"]
    
    private var sortedClasses: [ClassItem] {
        manager.timeTable[selectedDay].sorted(by: { $0.period < $1.period })
    }
    
    var body: some View {
        NavigationView {
            VStack {
                Picker("요일", selection: $selectedDay) {
                    ForEach(days, id: \.self) { day in
                        Text(day).tag(day)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                if isEditingMode {
                    addClassSection
                } else {
                    editToggleButton
                }
                
                classList
            }
            .navigationTitle("시간표")
            .alert("수업 정보 수정", isPresented: $isShowingEditAlert) {
                TextField("교시 (숫자)", text: $editingClassPeriod).keyboardType(.numberPad)
                TextField("과목 이름", text: $editingClassName)
                Button("취소", role: .cancel) { }
                Button("저장", action: updateClassInfo)
            }
        }
    }
    
    private var editToggleButton: some View {
        Button(action: {
            withAnimation {
                isEditingMode = true
                updateNextPeriod()
            }
        }) {
            Label("시간표 수정하기", systemImage: "pencil.circle.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.orange)
                .foregroundColor(.white)
                .cornerRadius(12)
        }
        .padding(.horizontal)
    }
    
    private var addClassSection: some View {
        VStack(spacing: 15) {
            HStack {
                Text("수업 추가").font(.headline)
                Spacer()
                Button("완료") { withAnimation { isEditingMode = false } }
                    .font(.headline)
            }
            
            HStack {
                Stepper("\(newClassPeriod)교시", value: $newClassPeriod, in: 1...10)
                    .fixedSize()
                
                TextField("수업 이름 입력", text: $newClassName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button(action: addClass) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
                .disabled(newClassName.isEmpty)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private var classList: some View {
        List {
            ForEach(sortedClasses) { classItem in
                classRow(for: classItem)
            }
            .onDelete(perform: deleteClass)
        }
        .environment(\.editMode, isEditingMode ? .constant(.active) : .constant(.inactive))
    }
    
    private func classRow(for classItem: ClassItem) -> some View {
        let totalItems = classItem.items.count
        let incompleteItems = classItem.items.filter { !$0.isCompleted }.count
        let itemsCountText: String
        
        if totalItems == 0 {
            itemsCountText = "없음"
        } else if incompleteItems == 0 {
            itemsCountText = "다 챙김"
        }
        else {
            itemsCountText = "\(totalItems)/\(incompleteItems)"
        }
        
        return HStack {
            Text("\(classItem.period)교시")
                .font(.subheadline)
                .foregroundColor(.blue)
                .frame(width: 45, alignment: .leading)
            
            Text(classItem.name)
                .onTapGesture {
                    if isEditingMode {
                        editingClassID = classItem.id
                        editingClassName = classItem.name
                        editingClassPeriod = String(classItem.period)
                        isShowingEditAlert = true
                    }
                }
            
            Spacer()
            
            if !isEditingMode {
                NavigationLink(destination: ClassDetailView(classItem: classItem, selectedDay: selectedDay)) {
                    Text("준비물 \(itemsCountText)")
                        .font(.caption).foregroundColor(.gray)
                }
            }
        }
    }
    
    private func updateClassInfo() {
        guard let id = editingClassID,
              let index = manager.timeTable[selectedDay].firstIndex(where: { $0.id == id }),
              let newPeriod = Int(editingClassPeriod) else { return }
        
        var currentDayClasses = manager.timeTable[selectedDay]
        currentDayClasses[index].name = editingClassName
        currentDayClasses[index].period = newPeriod
        manager.timeTable[selectedDay] = currentDayClasses
    }
    
    private func addClass() {
        let newItem = ClassItem(name: newClassName, period: newClassPeriod, items: [])
        var currentDayClasses = manager.timeTable[selectedDay]
        currentDayClasses.append(newItem)
        manager.timeTable[selectedDay] = currentDayClasses
        
        newClassName = ""
        updateNextPeriod()
    }
    
    private func deleteClass(at offsets: IndexSet) {
        let items = sortedClasses
        let idsToDelete = offsets.map { items[$0].id }
        
        var currentDayClasses = manager.timeTable[selectedDay]
        
        for id in idsToDelete {
            if let indexInCurrent = currentDayClasses.firstIndex(where: { $0.id == id }) {
                let deletedPeriod = currentDayClasses[indexInCurrent].period
                currentDayClasses.remove(at: indexInCurrent)
                for i in 0..<currentDayClasses.count where currentDayClasses[i].period > deletedPeriod {
                    currentDayClasses[i].period -= 1
                }
            }
        }
        manager.timeTable[selectedDay] = currentDayClasses
        updateNextPeriod()
    }
    
    private func updateNextPeriod() {
        let maxPeriod = manager.timeTable[selectedDay].map { $0.period }.max() ?? 0
        newClassPeriod = min(maxPeriod + 1, 10)
    }
}

struct ClassDetailView: View {
    @EnvironmentObject var manager: SchoolDataManager
    var classItem: ClassItem
    var selectedDay: String
    @State private var newItemName: String = ""
    
    var body: some View {
        VStack {
            HStack {
                TextField("새 준비물", text: $newItemName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Button("추가", action: addItem)
                    .disabled(newItemName.isEmpty)
            }
            .padding()
            
            List {
                if let classIndex = manager.timeTable[selectedDay].firstIndex(where: { $0.id == classItem.id }) {
                    ForEach(manager.timeTable[selectedDay][classIndex].items) { item in
                        HStack {
                            Button(action: { toggleItem(item, in: classIndex) }) {
                                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(item.isCompleted ? .green : .gray)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Text(item.name)
                                .strikethrough(item.isCompleted, color: .gray)
                                .foregroundColor(item.isCompleted ? .gray : .primary)
                        }
                    }
                    .onDelete { offsets in
                        var currentDayClasses = manager.timeTable[selectedDay]
                        currentDayClasses[classIndex].items.remove(atOffsets: offsets)
                        manager.timeTable[selectedDay] = currentDayClasses
                    }
                }
            }
        }
        .navigationTitle("\(classItem.name) 준비물")
    }
    
    private func toggleItem(_ item: TodoItem, in classIndex: Int) {
        var currentDayClasses = manager.timeTable[selectedDay]
        if let itemIndex = currentDayClasses[classIndex].items.firstIndex(where: { $0.id == item.id }) {
            currentDayClasses[classIndex].items[itemIndex].isCompleted.toggle()
            manager.timeTable[selectedDay] = currentDayClasses
        }
    }
    
    private func addItem() {
        if let index = manager.timeTable[selectedDay].firstIndex(where: { $0.id == classItem.id }) {
            var currentDayClasses = manager.timeTable[selectedDay]
            currentDayClasses[index].items.append(TodoItem(name: newItemName))
            manager.timeTable[selectedDay] = currentDayClasses
            newItemName = ""
        }
    }
}

struct DDayView: View {
    @EnvironmentObject var manager: SchoolDataManager
    @State private var newScheduleName: String = ""
    @State private var newScheduleDate: Date = Date()
    
    private var sortedSchedules: [ScheduleItem] {
        manager.schedules.sorted(by: { $0.date < $1.date })
    }
    
    private var formattedCurrentDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd EEEE"
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: Date())
    }
    
    var body: some View {
        NavigationView {
            VStack {
                Text("현재날짜 : \(formattedCurrentDate)")
                    .font(.headline).padding(.top)
                
                VStack {
                    TextField("일정 이름", text: $newScheduleName).textFieldStyle(RoundedBorderTextFieldStyle())
                    DatePicker("날짜 선택", selection: $newScheduleDate, displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "ko_KR"))
                    
                    Button("일정 추가", action: addSchedule)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(newScheduleName.isEmpty ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .disabled(newScheduleName.isEmpty)
                }
                .padding()
                
                List {
                    ForEach(sortedSchedules) { schedule in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(schedule.name)
                                Text(schedule.date.formatted(date: .numeric, time: .omitted))
                                    .font(.caption).foregroundColor(.gray)
                            }
                            Spacer()
                            Text(calculateDDay(targetDate: schedule.date)).fontWeight(.bold)
                        }
                    }
                    .onDelete(perform: deleteSchedule)
                }
            }
            .navigationTitle("D-day 일정")
        }
    }
    
    private func calculateDDay(targetDate: Date) -> String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: calendar.startOfDay(for: Date()), to: calendar.startOfDay(for: targetDate))
        guard let day = components.day else { return "" }
        
        if day > 0 { return "D-\(day)" }
        if day == 0 { return "D-Day" }
        return "종료"
    }
    
    private func addSchedule() {
        manager.schedules.append(ScheduleItem(name: newScheduleName, date: newScheduleDate))
        newScheduleName = ""
    }
    
    private func deleteSchedule(at offsets: IndexSet) {
        let schedulesToRemove = offsets.map { sortedSchedules[$0].id }
        manager.schedules.removeAll { schedule in
            schedulesToRemove.contains(schedule.id)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(SchoolDataManager())
}

