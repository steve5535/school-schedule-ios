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
// 앱에서 사용하는 데이터 구조 정의

struct TodoItem: Identifiable, Codable {
    var id = UUID()
    var name: String
    var isCompleted: Bool = false
}

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
    
    // 요일 문자열을 통해 해당 배열에 접근할 수 있게 해주는 서브스크립트
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
// 앱의 데이터를 관리하고 파일 시스템(JSON)에 저장/로드하는 역할을 담당

class SchoolDataManager: ObservableObject {
    @Published var timeTable = TimeTableData()
    @Published var schedules: [ScheduleItem] = []
    
    private let timeTableFileName = "timetable.json"
    private let scheduleFileName = "schedule_dday.json"
    
    init() {
        loadData()
    }
    
    // 앱 전용 문서 디렉토리 경로 가져오기
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    // 현재 상태를 JSON 파일로 저장
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
    
    // 저장된 JSON 파일에서 데이터를 읽어와 변수에 할당
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
// 하단 탭바를 통해 시간표와 D-day 뷰를 전환

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
// 요일별 수업 목록을 확인하고 수업을 추가/수정/삭제하는 화면

struct TimeTableView: View {
    @EnvironmentObject var manager: SchoolDataManager
    @State private var selectedDay: String = "월"
    @State private var newClassName: String = ""
    
    // 과목 이름 수정을 위한 상태 변수
    @State private var isShowingEditAlert = false
    @State private var editingClassID: UUID? = nil
    @State private var editingClassName: String = ""
    
    let days = ["월", "화", "수", "목", "금"]
    
    var body: some View {
        NavigationView {
            VStack {
                // 요일 선택 피커
                Picker("요일", selection: $selectedDay) {
                    ForEach(days, id: \.self) { day in
                        Text(day).tag(day)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // 새 수업 추가 입력란
                HStack {
                    TextField("새 수업 이름", text: $newClassName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Button(action: addClass) {
                        Image(systemName: "plus.circle.fill").font(.title2)
                    }
                    .disabled(newClassName.isEmpty)
                }
                .padding(.horizontal)
                
                // 수업 목록 표시
                List {
                    ForEach(manager.timeTable[selectedDay]) { classItem in
                        HStack {
                            Text(classItem.name)
                                .onTapGesture {
                                    // 텍스트 클릭 시 수정 알림창 표시
                                    editingClassID = classItem.id
                                    editingClassName = classItem.name
                                    isShowingEditAlert = true
                                }
                            Spacer()
                            // 준비물 상세 화면으로 이동하는 링크
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
    
    // 과목명 업데이트 로직
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

// MARK: - Class Detail View
// 특정 수업의 준비물 체크리스트를 관리하는 화면

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
                // 원본 데이터의 인덱스를 찾아 직접 접근하여 업데이트
                if let classIndex = manager.timeTable[selectedDay].firstIndex(where: { $0.id == classItem.id }) {
                    ForEach(manager.timeTable[selectedDay][classIndex].items) { item in
                        HStack {
                            // 완료 여부 토글 버튼
                            Button(action: { toggleItem(item, in: classIndex) }) {
                                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(item.isCompleted ? .green : .gray)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            // 완료 시 취소선 표시
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
// 중요한 시험이나 일정을 등록하고 남은 일수를 계산해주는 화면

struct DDayView: View {
    @EnvironmentObject var manager: SchoolDataManager
    @State private var newScheduleName: String = ""
    @State private var newScheduleDate: Date = Date()
    
    var body: some View {
        NavigationView {
            VStack {
                // 상단 오늘 날짜 표시
                Text(getTodayString()).font(.headline).padding(.top)
                
                // 일정 등록 섹션
                VStack {
                    TextField("일정 이름", text: $newScheduleName).textFieldStyle(RoundedBorderTextFieldStyle())
                    DatePicker("날짜 선택", selection: $newScheduleDate, displayedComponents: .date)
                        .datePickerStyle(CompactDatePickerStyle())
                        .environment(\.locale, Locale(identifier: "ko_KR"))
                    Button("일정 추가") { addSchedule() }
                        .frame(maxWidth: .infinity).padding().background(Color.blue).foregroundColor(.white).cornerRadius(8)
                }
                .padding()
                
                // 날짜순으로 정렬된 일정 목록
                List {
                    ForEach(manager.schedules.sorted(by: { $0.date < $1.date })) { schedule in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(schedule.name)
                                Text(formatDate(schedule.date)).font(.caption).foregroundColor(.gray)
                            }
                            Spacer()
                            // 계산된 D-Day 표시
                            Text(calculateDDay(targetDate: schedule.date)).fontWeight(.bold)
                        }
                    }
                    .onDelete(perform: deleteSchedule)
                }
            }
            .navigationTitle("D-day 일정")
        }
    }
    
    // 오늘의 날짜를 한국어 형식으로 반환
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
    
    // 현재 날짜와 대상 날짜 사이의 차이를 계산
    func calculateDDay(targetDate: Date) -> String {
        let calendar = Calendar.current
        // 시간 단위를 무시하고 날짜 차이만 계산하기 위해 startOfDay 사용
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
        // 정렬된 리스트에서의 인덱스를 실제 원본 배열의 인덱스로 매칭하여 삭제
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
