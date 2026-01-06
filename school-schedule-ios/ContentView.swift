import SwiftUI
import Combine

// MARK: - 앱의 시작점
@main
struct MySchoolApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// MARK: - 데이터 모델

// 준비물 개별 아이템 모델 (새로 추가)
struct TodoItem: Identifiable, Codable {
    var id = UUID()
    var name: String
    var isCompleted: Bool = false
}

// 수업 정보 모델 (items 타입을 TodoItem으로 변경)
struct ClassItem: Identifiable, Codable {
    var id = UUID()
    var name: String
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

// MARK: - 데이터 매니저
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
            print("저장 실패")
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

// MARK: - 메인 뷰
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

// MARK: - 시간표 탭 뷰 (수정 기능 포함)
struct TimeTableView: View {
    @EnvironmentObject var manager: SchoolDataManager
    @State private var selectedDay: String = "월"
    @State private var newClassName: String = ""
    
    // 수정 관련 상태
    @State private var isShowingEditAlert = false
    @State private var editingClassID: UUID? = nil
    @State private var editingClassName: String = ""
    
    let days = ["월", "화", "수", "목", "금"]
    
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
                
                HStack {
                    TextField("새 수업 이름", text: $newClassName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Button(action: addClass) {
                        Image(systemName: "plus.circle.fill").font(.title2)
                    }
                    .disabled(newClassName.isEmpty)
                }
                .padding(.horizontal)
                
                List {
                    ForEach(manager.timeTable[selectedDay]) { classItem in
                        HStack {
                            Text(classItem.name)
                                .onTapGesture {
                                    editingClassID = classItem.id
                                    editingClassName = classItem.name
                                    isShowingEditAlert = true
                                }
                            Spacer()
                            NavigationLink(destination: ClassDetailView(classItem: classItem, selectedDay: selectedDay)) {
                                Text("준비물 \(classItem.items.count)")
                                    .font(.caption).foregroundColor(.gray)
                            }
                        }
                    }
                    .onDelete(perform: deleteClass)
                }
            }
            .navigationTitle("시간표")
            .alert("과목 수정", isPresented: $isShowingEditAlert) {
                TextField("과목 이름", text: $editingClassName)
                Button("취소", role: .cancel) { }
                Button("저장") { updateClassName() }
            }
        }
    }
    
    func updateClassName() {
        if let id = editingClassID, let index = manager.timeTable[selectedDay].firstIndex(where: { $0.id == id }) {
            manager.timeTable[selectedDay][index].name = editingClassName
            manager.saveData()
        }
    }
    
    func addClass() {
        manager.timeTable[selectedDay].append(ClassItem(name: newClassName, items: []))
        manager.saveData()
        newClassName = ""
    }
    
    func deleteClass(at offsets: IndexSet) {
        manager.timeTable[selectedDay].remove(atOffsets: offsets)
        manager.saveData()
    }
}

// MARK: - 준비물 상세 뷰 (체크박스 & 취소선 포함)
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

// MARK: - D-day 뷰 (기존과 동일)
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
                    // DDayView 내부의 DatePicker 부분
                    DatePicker("날짜 선택", selection: $newScheduleDate, displayedComponents: .date)
                        .datePickerStyle(CompactDatePickerStyle())
                        .environment(\.locale, Locale(identifier: "ko_KR")) // 이 줄을 추가하면 달력이 한글로 나옵니다!
                    Button("일정 추가") { addSchedule() }
                        .frame(maxWidth: .infinity).padding().background(Color.blue).foregroundColor(.white).cornerRadius(8)
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
