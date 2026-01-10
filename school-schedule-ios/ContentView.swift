import SwiftUI
import Combine

@main
struct MySchoolApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// MARK: - Data Models

struct TodoItem: Identifiable, Codable {
    var id = UUID()
    var name: String
    var isCompleted: Bool = false
}

struct ClassItem: Identifiable, Codable {
    var id = UUID()
    var name: String
    var period: Int 
    var items: [TodoItem]
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

// MARK: - Data Manager

class SchoolDataManager: ObservableObject {
    @Published var timeTable = TimeTableData()
    @Published var schedules: [ScheduleItem] = []
    
    private let timeTableFileName = "timetable.json"
    private let scheduleFileName = "schedule_dday.json"
    
    init() {
        loadData()
    }
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    func saveData() {
        let encoder = JSONEncoder()
        do {
            let timeTableData = try encoder.encode(timeTable)
            try timeTableData.write(to: getDocumentsDirectory().appendingPathComponent(timeTableFileName))
            let scheduleData = try encoder.encode(schedules)
            try scheduleData.write(to: getDocumentsDirectory().appendingPathComponent(scheduleFileName))
        } catch {
            print("데이터 저장 중 오류 발생")
        }
    }
    
    func loadData() {
        let decoder = JSONDecoder()
        let timeTableURL = getDocumentsDirectory().appendingPathComponent(timeTableFileName)
        if let data = try? Data(contentsOf: timeTableURL),
           let decoded = try? decoder.decode(TimeTableData.self, from: data) {
            timeTable = decoded
        }
        let scheduleURL = getDocumentsDirectory().appendingPathComponent(scheduleFileName)
        if let data = try? Data(contentsOf: scheduleURL),
           let decoded = try? decoder.decode([ScheduleItem].self, from: data) {
            schedules = decoded
        }
    }
}

// MARK: - Main Content View

struct ContentView: View {
    @StateObject var dataManager = SchoolDataManager()
    
    var body: some View {
        TabView {
            TimeTableView()
                .tabItem {
                    Image(systemName: "calendar")
                    Text("시간표")
                }
                .environmentObject(dataManager)
            
            DDayView()
                .tabItem {
                    Image(systemName: "clock")
                    Text("D-day")
                }
                .environmentObject(dataManager)
        }
    }
}

// MARK: - TimeTable View

struct TimeTableView: View {
    @EnvironmentObject var manager: SchoolDataManager
    @State private var selectedDay: String = "월"
    @State private var isEditingMode = false
    
    @State private var newClassName: String = ""
    @State private var newClassPeriod: Int = 1
    
    @State private var isShowingEditAlert = false
    @State private var editingClassID: UUID? = nil
    @State private var editingClassName: String = ""
    @State private var editingClassPeriod: String = "" 
    
    let days = ["월", "화", "수", "목", "금"]
    
    var body: some View {
        NavigationView {
            VStack {
                dayPicker
                
                if !isEditingMode {
                    editToggleButton
                } else {
                    addClassSection
                }
                
                classList
            }
            .navigationTitle("시간표")
            .alert("수업 정보 수정", isPresented: $isShowingEditAlert) {
                editAlertActions
            }
        }
    }
    
    private var dayPicker: some View {
        Picker("요일", selection: $selectedDay) {
            ForEach(days, id: \.self) { day in
                Text(day).tag(day)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding()
    }
    
    private var editToggleButton: some View {
        Button(action: { 
            withAnimation { 
                isEditingMode = true 
                updateNextPeriod() // 수정 모드 진입 시 다음 교시 번호 맞춤
            } 
        }) {
            HStack {
                Image(systemName: "pencil.circle.fill")
                Text("시간표 수정하기")
            }
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
                Button("완료") {
                    withAnimation {
                        isEditingMode = false
                        newClassName = ""
                    }
                }
                .font(.headline)
                .foregroundColor(.blue)
            }
            
            HStack {
                Stepper("\(newClassPeriod)교시", value: $newClassPeriod, in: 1...10)
                    .frame(width: 130)
                
                TextField("수업 이름 입력", text: $newClassName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button(action: addClass) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(newClassName.isEmpty ? .gray : .green)
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
            ForEach(manager.timeTable[selectedDay].sorted(by: { $0.period < $1.period })) { classItem in
                classRow(for: classItem)
            }
            // 수정 모드일 때만 삭제 가능
            .onDelete(perform: isEditingMode ? { offsets in deleteClass(at: offsets) } : nil)
        }
        // 수정 모드일 때 리스트에 편집 UI(마이너스 버튼) 표시
        .environment(\.editMode, isEditingMode ? .constant(.active) : .constant(.inactive))
    }
    
    private func classRow(for classItem: ClassItem) -> some View {
        HStack {
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
                    Text("준비물 \(classItem.items.count)")
                        .font(.caption).foregroundColor(.gray)
                }
            }
        }
    }
    
    @ViewBuilder
    private var editAlertActions: some View {
        TextField("교시 (숫자)", text: $editingClassPeriod)
            .keyboardType(.numberPad)
        TextField("과목 이름", text: $editingClassName)
        Button("취소", role: .cancel) { }
        Button("저장") { updateClassInfo() }
    }
    
    // MARK: - Logic
    
    func updateClassInfo() {
        if let id = editingClassID, 
           let index = manager.timeTable[selectedDay].firstIndex(where: { $0.id == id }),
           let newPeriod = Int(editingClassPeriod) {
            manager.timeTable[selectedDay][index].name = editingClassName
            manager.timeTable[selectedDay][index].period = newPeriod
            manager.timeTable[selectedDay].sort(by: { $0.period < $1.period })
            manager.saveData()
            updateNextPeriod()
        }
    }
    
    func addClass() {
        let newItem = ClassItem(name: newClassName, period: newClassPeriod, items: [])
        manager.timeTable[selectedDay].append(newItem)
        manager.timeTable[selectedDay].sort(by: { $0.period < $1.period })
        manager.saveData()
        
        newClassName = ""
        updateNextPeriod()
    }
    
    func deleteClass(at offsets: IndexSet) {
        // 현재 요일의 정렬된 리스트 복사본
        var items = manager.timeTable[selectedDay].sorted(by: { $0.period < $1.period })
        
        // 삭제할 아이템들의 ID를 미리 추출 (인덱스 변화에 영향받지 않기 위함)
        let idsToDelete = offsets.map { items[$0].id }
        
        for id in idsToDelete {
            if let index = items.firstIndex(where: { $0.id == id }) {
                let deletedPeriod = items[index].period
                items.remove(at: index)
                
                // 삭제된 교시보다 뒷 순서의 수업들을 한 교시씩 앞으로 당김
                for i in 0..<items.count {
                    if items[i].period > deletedPeriod {
                        items[i].period -= 1
                    }
                }
            }
        }
        
        // 변경 사항을 데이터 매니저에 반영
        manager.timeTable[selectedDay] = items
        manager.saveData()
        updateNextPeriod()
    }
    
    // 다음 입력할 교시를 마지막 교시 + 1로 자동 업데이트
    private func updateNextPeriod() {
        let maxPeriod = manager.timeTable[selectedDay].map { $0.period }.max() ?? 0
        newClassPeriod = min(maxPeriod + 1, 10)
    }
}

// MARK: - Class Detail View

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
                Button("추가") { addItem() }
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
                    .onDelete { offsets in deleteItem(at: offsets, classIndex: classIndex) }
                }
            }
        }
        .navigationTitle("\(classItem.name) 준비물")
    }
    
    func toggleItem(_ item: TodoItem, in classIndex: Int) {
        if let itemIndex = manager.timeTable[selectedDay][classIndex].items.firstIndex(where: { $0.id == item.id }) {
            manager.timeTable[selectedDay][classIndex].items[itemIndex].isCompleted.toggle()
            manager.saveData()
        }
    }
    
    func addItem() {
        if let index = manager.timeTable[selectedDay].firstIndex(where: { $0.id == classItem.id }) {
            manager.timeTable[selectedDay][index].items.append(TodoItem(name: newItemName))
            manager.saveData()
            newItemName = ""
        }
    }
    
    func deleteItem(at offsets: IndexSet, classIndex: Int) {
        manager.timeTable[selectedDay][classIndex].items.remove(atOffsets: offsets)
        manager.saveData()
    }
}

// MARK: - D-Day View

struct DDayView: View {
    @EnvironmentObject var manager: SchoolDataManager
    @State private var newScheduleName: String = ""
    @State private var newScheduleDate: Date = Date()
    
    var body: some View {
        NavigationView {
            VStack {
                Text(getTodayString()).font(.headline).padding(.top)
                
                VStack {
                    TextField("일정 이름", text: $newScheduleName).textFieldStyle(RoundedBorderTextFieldStyle())
                    DatePicker("날짜 선택", selection: $newScheduleDate, displayedComponents: .date)
                        .datePickerStyle(CompactDatePickerStyle())
                        .environment(\.locale, Locale(identifier: "ko_KR"))
                    
                    Button("일정 추가") { addSchedule() }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(newScheduleName.isEmpty ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .disabled(newScheduleName.isEmpty)
                }
                .padding()
                
                List {
                    ForEach(manager.schedules.sorted(by: { $0.date < $1.date })) { schedule in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(schedule.name)
                                Text(formatDate(schedule.date)).font(.caption).foregroundColor(.gray)
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
    
    func getTodayString() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년 MM월 dd일 EEEE"
        return formatter.string(from: Date())
    }
    
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    func calculateDDay(targetDate: Date) -> String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: calendar.startOfDay(for: Date()), to: calendar.startOfDay(for: targetDate))
        if let day = components.day {
            if day > 0 { return "D-\(day)" }
            else if day == 0 { return "D-Day" }
            else { return "종료" }
        }
        return ""
    }
    
    func addSchedule() {
        guard !newScheduleName.isEmpty else { return }
        
        manager.schedules.append(ScheduleItem(name: newScheduleName, date: newScheduleDate))
        manager.saveData()
        newScheduleName = ""
    }
    
    func deleteSchedule(at offsets: IndexSet) {
        let sorted = manager.schedules.sorted(by: { $0.date < $1.date })
        offsets.forEach { index in
            let itemToDelete = sorted[index]
            if let originalIndex = manager.schedules.firstIndex(where: { $0.id == itemToDelete.id }) {
                manager.schedules.remove(at: originalIndex)
            }
        }
        manager.saveData()
    }
}

#Preview {
    ContentView()
}

