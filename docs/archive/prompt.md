1. 既存のコードをベースとして機能を追加するため、「# 既存の WebApp.js」967行と「# 既存の index.html」1546行より減ることはあり得ません。既存の機能は必ず維持してください。生成されたファイルが「WebApp.js」1083行、「index.html」1174行となっている省略されたコードを特定してください。
2. 一度にコード全文を生成すると、Gemini仕様上タイムアウトになる恐れがあります。「メンテナンスの観点から最適化されたアーキテクスチャに応じてファイルを分割」「プロンプトにつき生成するファイルは1ファイルとし、次のファイルは次のプロンプトへ渡す」などの対策を講じる。
3. 「1つのバックエンドファイル (WebApp.js)」 と 「1つのフロントエンドファイル (index.html)」 に集約した構成である必要はありません。2.の通りGemini仕様上によるコード生成中のタイムアウトを防止するため、「複数のバックエンドファイル (WebApp.js)」 と 「複数のフロントエンドファイル (index.html)」としても問題ありません。
4. 「仕様書」「実装手順書」などを生成してください。VSCodeを使用します。コード全文をコピペして実装する手順は維持します。

# 既存の WebApp.js

/\*\*
 * BizLaw Master - Backend Logic
 * Version: 28.1 (Maintenance: Keep version sync)
 \*/

// --- Configuration ---
function getSpreadsheetId() {
  return PropertiesService.getScriptProperties().getProperty("SS_ID") || "1p-CDMMTewjYihGicGzyLF0Q-UI6iv6RPT8GwENPLzqg";
}

const DATA_VERSION = "v28_1_cat3_update"; 

const SHEET_KEYS = {
  EXAMS: "exams",           
  INSTANCES: "exam_instances",
  SCENARIOS: "scenarios",
  QUESTIONS: "questions",
  CHOICES: "choices",
  HISTORY: "history",
  FLAGS: "review_flags",
  SETTINGS: "user_settings",
  SORT_MASTER: "sort_master",
  LABELS: "labels",
  REPORTS: "reports"
};

// --- Web App Entry Point ---
function doGet(e) {
  if (e.parameter.reset === 'true') {
    clearServerCache();
    return ContentService.createTextOutput("Cache Cleared.");
  }

  const userId = \_resolveUserId(e.parameter.userId);
  const template = HtmlService.createTemplateFromFile('index');

  try {
    const settings = getUserSettings(userId);
    if (settings) settings.userId = userId;
    template.initialSettings = JSON.stringify(settings);
  } catch (e) {
    template.initialSettings = JSON.stringify({ userId: userId });
  }

  return template.evaluate()
    .setTitle('BizLaw Master')
    .addMetaTag('viewport', 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no')
    .setXFrameOptionsMode(HtmlService.XFrameOptionsMode.ALLOWALL);
}

// --- API Functions ---

function getInitialData(providedId) {
  const userId = \_resolveUserId(providedId);
  const ss = SpreadsheetApp.openById(getSpreadsheetId());

  const checkList = [SHEET_KEYS.EXAMS, SHEET_KEYS.INSTANCES, SHEET_KEYS.QUESTIONS];
  const missing = [];
  checkList.forEach(key => {
    if (!\_getSheetByKeyStrict(ss, key)) missing.push(key);
  });

  if (missing.length > 0) {
    return { error: "SHEET_MISSING", missing: missing };
  }

  try {
    const exams = \_getCachedSheetData(SHEET_KEYS.EXAMS) || [];
    const instances = \_getCachedSheetData(SHEET_KEYS.INSTANCES) || [];
    const questions = \_getCachedSheetData(SHEET_KEYS.QUESTIONS) || [];
    const scenarios = \_getCachedSheetData(SHEET_KEYS.SCENARIOS) || [];
    const sortMaster = \_getCachedSheetData(SHEET_KEYS.SORT_MASTER) || [];

    // JOIN: exams + instances
    const examMap = new Map();
    exams.forEach(e => {
      const id = String(e.exam_id || e.id || "").trim();
      if (id) examMap.set(id, e);
    });

    const enrichedInstances = instances.map(inst => {
      const examId = String(inst.exam_id || "").trim();
      const examInfo = examMap.get(examId);

      
      const name = examInfo ? (examInfo.exam_name || examInfo.name) : (inst.exam_name || '不明な試験');
      const grade = examInfo ? (examInfo.exam_grade || examInfo.grade) : (inst.exam_grade || '');

      
      return { ...inst, exam_name: name, exam_grade: grade };
    });

    const userHistoryData = \_fetchUserHistory(ss, userId);
    const fData = \_readSheetByKey(ss, SHEET_KEYS.FLAGS);
    const historyMap = \_mapUserHistory(userHistoryData);
    const flagSet = \_getUserFlagSet(fData, userId);

    const scenarioNoMap = new Map();
    scenarios.forEach(s => {
      scenarioNoMap.set(String(s.scenario_id), s.scenario_no);
    });

    const instanceMap = new Map();
    enrichedInstances.forEach(i => {
      instanceMap.set(String(i.instance_id).trim(), i);
    });

    const questionsMeta = questions.map(q => {
      if (!q.question_id) return null;
      if (!q.question_text && !q.question_image) return null;

      const qId = String(q.question_id);
      const historyList = historyMap[qId] || [];
      const latestHistory = historyList.length > 0 ? historyList[historyList.length - 1] : null;

      
      const qInstId = String(q.instance_id || "").trim();
      const instance = instanceMap.get(qInstId);

      
      const examName = instance ? instance.exam_name : '未分類';
      const examGrade = instance ? instance.exam_grade : '';
      const examEdition = instance ? (instance.exam_edition || instance.edition || '') : '';
      const examType = instance ? (instance.exam_type || instance.type || '') : '';
      const examLabel = `${examEdition} ${examGrade}`;

      
      const sNo = q.scenario_id ? scenarioNoMap.get(String(q.scenario_id)) : (q.scenario_no || null);

      return {
        id: q.question_id,
        text: q.question_text ? String(q.question_text).substring(0, 60) + '...' : '',
        question_no: q.question_no,
        scenario_no: sNo,
        category: q.category_1 || '未分類',
        category2: q.category_2 || null,
        category3: q.category_3 || null,
        exam: examLabel, 
        examName: examName,
        examId: instance ? instance.exam_id : null,
        grade: examGrade,
        type: examType,
        answer_type: q.answer_type || 'SCMC',
        isCorrect: latestHistory ? latestHistory.isCorrect : null,
        isFlagged: flagSet.has(qId),
        history: historyList.map(h => h.isCorrect)
      };
    }).filter(Boolean);

    return {
      success: true,
      userId: userId,
      exams: exams, 
      instances: enrichedInstances,
      sortMaster: sortMaster,
      questionsMeta: questionsMeta
    };

  } catch (e) {
    console.error("getInitialData Error:", e);
    return { error: "DATA_LOAD_ERROR", message: e.message, stack: e.stack };
  }
}

// 単一問題の取得
function getQuestionDetail(providedId, questionId) {
  const result = getQuestionsByIds(providedId, [questionId]);
  return result.length > 0 ? result : [];
}

function getQuestionsByIds(providedId, questionIds) {
  const userId = \_resolveUserId(providedId);
  if (!questionIds || !Array.isArray(questionIds) || questionIds.length === 0) return [];

  const qData = \_getCachedSheetData(SHEET_KEYS.QUESTIONS);
  const instances = \_getCachedSheetData(SHEET_KEYS.INSTANCES);
  const exams = \_getCachedSheetData(SHEET_KEYS.EXAMS);
  const cData = \_getCachedSheetData(SHEET_KEYS.CHOICES);
  const sData = \_getCachedSheetData(SHEET_KEYS.SCENARIOS);

  const targetIds = new Set(questionIds.map(id => String(id)));
  let filteredQuestions = qData.filter(q => targetIds.has(String(q.question_id)));

  
  filteredQuestions = \_validateQuestions(filteredQuestions, cData);
  if (filteredQuestions.length === 0) return [];

  const joinedQuestions = \_joinData(filteredQuestions, cData, sData, instances, exams);

  const orderMap = new Map();
  questionIds.forEach((id, index) => {
    orderMap.set(String(id), index);
  });

  joinedQuestions.sort((a, b) => {
    const idxA = orderMap.has(String(a.question_id)) ? orderMap.get(String(a.question_id)) : 99999;
    const idxB = orderMap.has(String(b.question_id)) ? orderMap.get(String(b.question_id)) : 99999;
    return idxA - idxB;
  });

  return joinedQuestions;
}

// 統計取得
function getUserStats(providedId, filters = {}) {
  const userId = \_resolveUserId(providedId);
  const ss = SpreadsheetApp.openById(getSpreadsheetId());

  
  const qData = \_getCachedSheetData(SHEET_KEYS.QUESTIONS);
  const instances = \_getCachedSheetData(SHEET_KEYS.INSTANCES);
  const exams = \_getCachedSheetData(SHEET_KEYS.EXAMS);

  let targetQuestions = qData.filter(q => q.question_text);
  if (filters && Object.keys(filters).length > 0) {
    targetQuestions = \_filterQuestions(targetQuestions, instances, exams, filters);
  }

  const targetQIds = new Set();
  targetQuestions.forEach(q => targetQIds.add(String(q.question_id)));

  const userRawHistory = \_fetchUserHistory(ss, userId);
  const relevantHistory = [];
  const historyMap = {};

  for (let i = 0; i < userRawHistory.length; i++) {
    const h = userRawHistory[i];
    const sId = String(h.question_id);
    if (targetQIds.has(sId)) {
        relevantHistory.push(h);
        if (!historyMap[sId]) historyMap[sId] = [];
        let ts = h.timestamp;
        if (!(ts instanceof Date)) ts = new Date(ts);

        
        historyMap[sId].push({
            isCorrect: (String(h.is_correct).toUpperCase() === 'TRUE'),
            timestamp: ts
        });
    }
  }

  
  Object.keys(historyMap).forEach(k => {
      historyMap[k].sort((a,b) => a.timestamp - b.timestamp);
  });

  let answeredCount = 0;
  let correctCount = 0;

  
  const categoryStats = {};
  const category2Stats = {};
  const typeStats = {};

  
  const instanceTypeMap = new Map();
  instances.forEach(i => instanceTypeMap.set(String(i.instance_id), i.exam_type || 'その他'));

  for (let i = 0; i < targetQuestions.length; i++) {
    const q = targetQuestions[i];
    const cat1 = q.category_1 || '未分類';
    const cat2 = q.category_2 || '未分類';
    const type = instanceTypeMap.get(String(q.instance_id)) || 'その他';

    if (!categoryStats[cat1]) categoryStats[cat1] = { total: 0, correct: 0, incorrect: 0, unanswered: 0 };
    if (!category2Stats[cat2]) category2Stats[cat2] = { total: 0, correct: 0, incorrect: 0, unanswered: 0, parent: cat1 };
    if (!typeStats[type]) typeStats[type] = { total: 0, correct: 0, incorrect: 0, unanswered: 0 };

    categoryStats[cat1].total++;
    category2Stats[cat2].total++;
    typeStats[type].total++;

    const historyList = historyMap[String(q.question_id)];
    if (historyList && historyList.length > 0) {
      answeredCount++;
      const latest = historyList[historyList.length - 1];
      if (latest.isCorrect) {
        correctCount++;
        categoryStats[cat1].correct++;
        category2Stats[cat2].correct++;
        typeStats[type].correct++;
      } else {
        categoryStats[cat1].incorrect++;
        category2Stats[cat2].incorrect++;
        typeStats[type].incorrect++;
      }
    } else {
      categoryStats[cat1].unanswered++;
      category2Stats[cat2].unanswered++;
      typeStats[type].unanswered++;
    }
  }

  const formatStats = (statsObj) => {
    return Object.keys(statsObj).map(key => {
      const item = statsObj[key];
      return {
        name: key,
        total: item.total,
        correct: item.correct,
        incorrect: item.incorrect,
        unanswered: item.unanswered,
        rate: item.total > 0 ? Math.round((item.correct / item.total) \* 100) : 0,
        parent: item.parent || null
      };
    }).sort((a, b) => b.rate - a.rate);
  };

  const weeklyActivity = \_calculateWeeklyActivity(relevantHistory);
  const estimatedTime = Math.round(relevantHistory.length \* 1.5);

  const uniqueDays = new Set();
  const TIMEZONE = "Asia/Tokyo";
  const FORMAT = "yyyy-MM-dd";
  relevantHistory.forEach(h => {
      if(h.timestamp) {
          try {
             uniqueDays.add(Utilities.formatDate(new Date(h.timestamp), TIMEZONE, FORMAT));
          } catch(e){}
      }
  });

  return {
    totalQuestions: targetQuestions.length,
    totalCount: answeredCount,
    correctCount: correctCount,
    accuracy: answeredCount > 0 ? Math.round((correctCount / answeredCount) \* 100) : 0,
    totalTime: estimatedTime,
    learningDays: uniqueDays.size,
    predictionDays: -1, 
    breakdown: {
      correct: correctCount,
      incorrect: answeredCount - correctCount,
      unanswered: targetQuestions.length - answeredCount
    },
    categoryList: formatStats(categoryStats),
    category2List: formatStats(category2Stats),
    typeList: formatStats(typeStats),
    weeklyActivity: weeklyActivity
  };
}

// フラグ付き問題
function getFlaggedQuestions(providedId, count = 20, filters = {}) {
  const userId = \_resolveUserId(providedId);
  const ss = SpreadsheetApp.openById(getSpreadsheetId());
  const fData = \_readSheetByKey(ss, SHEET_KEYS.FLAGS);
  const userFlags = \_getUserFlagSet(fData, userId);

  if (userFlags.size === 0) return [];

  const qData = \_getCachedSheetData(SHEET_KEYS.QUESTIONS);
  const instances = \_getCachedSheetData(SHEET_KEYS.INSTANCES);
  const exams = \_getCachedSheetData(SHEET_KEYS.EXAMS);
  const cData = \_getCachedSheetData(SHEET_KEYS.CHOICES);
  const sData = \_getCachedSheetData(SHEET_KEYS.SCENARIOS);
  const sortMaster = \_getCachedSheetData(SHEET_KEYS.SORT_MASTER);

  let candidateQuestions = \_filterQuestions(qData, instances, exams, filters);
  candidateQuestions = candidateQuestions.filter(q => userFlags.has(String(q.question_id)));
  candidateQuestions = \_validateQuestions(candidateQuestions, cData);

  if (candidateQuestions.length === 0) return [];

  const joinedQuestions = \_joinData(candidateQuestions, cData, sData, instances, exams);
  const getSortOrder = \_createSortHelper(sortMaster);

  
  joinedQuestions.sort((a, b) => {
      const cat1A = getSortOrder(a.category, 'category_1');
      const cat1B = getSortOrder(b.category, 'category_1');
      if (cat1A !== cat1B) return cat1A - cat1B;

      
      const cat2A = getSortOrder(a.category2, 'category_2', a.category);
      const cat2B = getSortOrder(b.category2, 'category_2', b.category);
      if (cat2A !== cat2B) return cat2A - cat2B;

      
      const cat3A = getSortOrder(a.category3, 'category_3', a.category2);
      const cat3B = getSortOrder(b.category3, 'category_3', b.category2);
      if (cat3A !== cat3B) return cat3A - cat3B;

      
      return (a.question_no || 0) - (b.question_no || 0);
  });

  return joinedQuestions;
}

function getSmartQuestions(providedId, count = 10, filters = {}) {
  const userId = \_resolveUserId(providedId);
  const ss = SpreadsheetApp.openById(getSpreadsheetId());

  
  const qData = \_getCachedSheetData(SHEET_KEYS.QUESTIONS);
  const instances = \_getCachedSheetData(SHEET_KEYS.INSTANCES);
  const exams = \_getCachedSheetData(SHEET_KEYS.EXAMS);
  const sortMaster = \_getCachedSheetData(SHEET_KEYS.SORT_MASTER);
  const cData = \_getCachedSheetData(SHEET_KEYS.CHOICES);

  let filteredQuestions = \_filterQuestions(qData, instances, exams, filters);
  filteredQuestions = \_validateQuestions(filteredQuestions, cData);

  if (filteredQuestions.length === 0) return [];

  const sData = \_getCachedSheetData(SHEET_KEYS.SCENARIOS);
  const questions = \_joinData(filteredQuestions, cData, sData, instances, exams);

  const userRawHistory = \_fetchUserHistory(ss, userId);
  const userHistory = \_mapUserHistory(userRawHistory);
  const fData = \_readSheetByKey(ss, SHEET_KEYS.FLAGS);
  const userFlags = \_getUserFlagSet(fData, userId);

  const now = new Date().getTime();
  const ONE_DAY_MS = 86400000;
  const getSortOrder = \_createSortHelper(sortMaster);

  const scoredQuestions = questions.map(q => {
    const qId = String(q.question_id);
    const historyList = userHistory[qId] || [];
    const latest = historyList.length > 0 ? historyList[historyList.length - 1] : null;
    const isFlagged = userFlags.has(qId);

    let score = 0;
    if (isFlagged) score = 100;
    else if (latest && !latest.isCorrect) score = 80;
    else if (!latest) score = 40;
    else {
      const elapsedDays = (now - latest.timestamp.getTime()) / ONE_DAY_MS;
      score = Math.min(30, elapsedDays \* 1.0);
    }

    
    if (score !== 40) score += Math.random() \* 5;

    const sortKey = 
      String(getSortOrder(q.category, 'category_1')).padStart(4, '0') +
      String(getSortOrder(q.category2, 'category_2', q.category)).padStart(4, '0') +
      String(getSortOrder(q.category3, 'category_3', q.category2)).padStart(4, '0') +
      String(q.question_no || 0).padStart(4, '0');

    return { ...q, score, sortKey };
  });

  scoredQuestions.sort((a, b) => {
    if (Math.floor(b.score) !== Math.floor(a.score)) return b.score - a.score;
    if (a.sortKey < b.sortKey) return -1;
    if (a.sortKey > b.sortKey) return 1;
    return 0;
  });

  return scoredQuestions.slice(0, count);
}

// 不備報告
function reportQuestionIssue(providedId, questionId, type, comment) {
  const userId = \_resolveUserId(providedId);
  const lock = LockService.getScriptLock();
  if (lock.tryLock(3000)) {
    try {
      const ss = SpreadsheetApp.openById(getSpreadsheetId());
      let sheet = \_getSheetByKeyStrict(ss, SHEET_KEYS.REPORTS);
      if (!sheet) {
        sheet = ss.insertSheet(SHEET_KEYS.REPORTS);
        sheet.appendRow(['timestamp', 'user_id', 'question_id', 'type', 'comment']);
      }
      sheet.appendRow([new Date(), userId, questionId, type, comment]);
      return { success: true };
    } catch(e) {
      console.error(e);
      return { error: e.message };
    } finally {
      lock.releaseLock();
    }
  }
  return { error: "Busy" };
}

function toggleReviewFlag(providedId, questionId) {
  const userId = \_resolveUserId(providedId);
  const lock = LockService.getScriptLock();
  if (lock.tryLock(3000)) {
    try {
      const ss = SpreadsheetApp.openById(getSpreadsheetId());
      let sheet = \_getSheetByKeyStrict(ss, SHEET_KEYS.FLAGS);
      if (!sheet) {
        sheet = ss.insertSheet(SHEET_KEYS.FLAGS);
        sheet.appendRow(['timestamp', 'user_id', 'question_id']);
      }
      const data = sheet.getDataRange().getValues();
      let foundRow = -1;
      let uIdx = 1, qIdx = 2;
      if(data.length > 0) {
         const h = data[0];
         for(let i=0; i<h.length; i++) {
           const key = String(h[i]).toLowerCase();
           if(key.includes('user')) uIdx = i;
           if(key.includes('question')) qIdx = i;
         }
      }
      for (let i = 1; i < data.length; i++) {
        if (String(data[i][uIdx]) === String(userId) && String(data[i][qIdx]) === String(questionId)) {
          foundRow = i + 1;
          break;
        }
      }
      if (foundRow > 0) {
        sheet.deleteRow(foundRow);
      } else {
        sheet.appendRow([new Date(), userId, questionId]);
      }
    } finally {
      lock.releaseLock();
    }
  }
}

// --- Helper Functions ---

function \_createSortHelper(sortMaster) {
    return (val, type, parentVal = null) => {
        if (!sortMaster) return 9999;
        let item;
        if (parentVal) item = sortMaster.find(row => row.master_type === type && row.value === val && row.parent_value_1 === parentVal);
        if (!item) item = sortMaster.find(row => row.master_type === type && row.value === val);
        return item ? (parseInt(item.sort_order) || 9999) : 9999;
    };
}

function _fetchUserHistory(ss, userId) {
  const sheet = \_getSheetByKeyStrict(ss, SHEET_KEYS.HISTORY);
  if (!sheet) return [];
  const values = sheet.getDataRange().getValues();
  if (values.length < 2) return [];
  const headers = values[0];
  const colMap = {};
  headers.forEach((h, i) => colMap[String(h).trim().toLowerCase().replace(/_/g,'')] = i);

  
  const uIdx = colMap['userid'];
  if (uIdx === undefined) return [];

  
  const userRows = [];
  const targetUserId = String(userId);
  const tsIdx = colMap['timestamp'];
  const qIdx = colMap['questionid'];
  const cIdx = colMap['iscorrect'];

  for (let i = 1; i < values.length; i++) {
    if (String(values[i][uIdx]) === targetUserId) {
      userRows.push({
        timestamp: values[i][tsIdx],
        question_id: values[i][qIdx],
        is_correct: values[i][cIdx]
      });
    }
  }
  return userRows;
}

function \_mapUserHistory(historyArray) {
  const map = {};
  historyArray.forEach(h => {
    const qId = String(h.question_id);
    if (!map[qId]) map[qId] = [];
    let ts = h.timestamp;
    if (!(ts instanceof Date)) ts = new Date(ts);

    
    map[qId].push({
      isCorrect: (String(h.is_correct).toUpperCase() === 'TRUE'),
      timestamp: ts
    });
  });
  return map;
}

function \_calculateWeeklyActivity(filteredHistory) {
  const today = new Date();
  const activityMap = new Map();
  const TIMEZONE = "Asia/Tokyo";
  const FORMAT = "yyyy-MM-dd";

  for (let i = 59; i >= 0; i--) {
    const d = new Date(today);
    d.setDate(today.getDate() - i);
    const key = Utilities.formatDate(d, TIMEZONE, FORMAT);
    activityMap.set(key, { date: key, count: 0 });
  }

  filteredHistory.forEach(h => {
    if (h.timestamp) {
      const key = Utilities.formatDate(new Date(h.timestamp), TIMEZONE, FORMAT);
      if (activityMap.has(key)) {
        const entry = activityMap.get(key);
        entry.count++;
      }
    }
  });
  return Array.from(activityMap.values());
}

function \_joinData(questions, choices, scenarios, instances, exams) {
  const choiceMap = {};
  choices.forEach(c => {
    const qId = String(c.question_id);
    if (!choiceMap[qId]) choiceMap[qId] = [];
    choiceMap[qId].push(c);
  });
  Object.keys(choiceMap).forEach(k => {
    choiceMap[k].sort((a,b) => (parseInt(a.choice_no)||0) - (parseInt(b.choice_no)||0));
  });

  const scenarioMap = {};
  if (scenarios) {
    scenarios.forEach(s => {
      scenarioMap[String(s.scenario_id)] = { text: s.scenario_text, no: s.scenario_no };
    });
  }

  const examMap = new Map();
  if (exams) {
    exams.forEach(e => examMap.set(String(e.exam_id || e.id).trim(), e));
  }

  
  const instanceMap = new Map();
  if (instances) {
    instances.forEach(i => {
      const examInfo = examMap.get(String(i.exam_id).trim());
      const joinedInstance = {
        ...i,
        exam_name: examInfo ? (examInfo.exam_name || examInfo.name) : (i.exam_name || '不明な試験'),
        exam_grade: examInfo ? (examInfo.exam_grade || examInfo.grade) : (i.exam_grade || '')
      };
      instanceMap.set(String(i.instance_id).trim(), joinedInstance);
    });
  }

  return questions.map(q => {
    const inst = q.instance_id ? instanceMap.get(String(q.instance_id).trim()) : null;

    
    let expl = q.explanation || "";
    if (expl) expl = expl.replace(/\n/g, "<br>");

    return {
      id: q.question_id,
      question_id: q.question_id,
      text: q.question_text,
      image: q.question_image || null,
      image_url: q.question_image_url || null,
      category: q.category_1,
      category2: q.category_2 || null,
      category3: q.category_3 || null,
      question_no: q.question_no,
      scenario_no: q.scenario_id && scenarioMap[String(q.scenario_id)] ? scenarioMap[String(q.scenario_id)].no : (q.scenario_no || null),
      explanation: expl,
      answer_type: q.answer_type || 'SCMC',
      correct: \_parseCorrectAnswer(q.correct_answer, q.answer_type),
      choices: (choiceMap[String(q.question_id)] || []).map(c => c.choice_text),
      scenario: q.scenario_id ? (scenarioMap[String(q.scenario_id)] || null) : null,

      
      exam_grade: inst ? inst.exam_grade : null,
      exam_edition: inst ? (inst.exam_edition || inst.edition) : null,
      exam_type: inst ? (inst.exam_type || inst.type) : null
    };
  });
}

function \_validateQuestions(questions, choices) {
  const choiceMap = new Set(choices.map(c => String(c.question_id)));
  return questions.filter(q => {
    if (!q.question_text) return false;
    if (q.answer_type !== 'TEXT' && !choiceMap.has(String(q.question_id))) return false;
    return true;
  });
}

function \_normalizeAnswer(val) {
  if (!val) return "";
  let s = String(val);
  s = s.replace(/[Ａ-Ｚａ-ｚ０-９]/g, function(s) {
    return String.fromCharCode(s.charCodeAt(0) - 0xFEE0);
  });
  s = s.replace(/\s+/g, "");
  return s.toLowerCase();
}

function \_parseCorrectAnswer(val, type) {
  if (!val) return 0;
  if (type === 'TEXT') return \_normalizeAnswer(val);

  
  if (typeof val === 'number') return val - 1;
  const num = parseInt(val);
  if (!isNaN(num)) return num - 1;

  
  const kana = ['ア', 'イ', 'ウ', 'エ', 'オ'];
  const idx = kana.indexOf(val);
  return idx >= 0 ? idx : 0;
}

function saveHistory(providedId, questionId, userChoiceIndex, isCorrect) {
  const userId = \_resolveUserId(providedId);
  const lock = LockService.getScriptLock();

  
  let savedAnswer = userChoiceIndex;
  if (typeof userChoiceIndex === 'string') savedAnswer = \_normalizeAnswer(userChoiceIndex);

  if (lock.tryLock(3000)) {
    try {
      const ss = SpreadsheetApp.openById(getSpreadsheetId());
      let sheet = \_getSheetByKeyStrict(ss, SHEET_KEYS.HISTORY);
      if (!sheet) {
         sheet = ss.insertSheet(SHEET_KEYS.HISTORY);
         sheet.appendRow(['timestamp','user_id','question_id','user_answer','is_correct']);
      }
      sheet.appendRow([new Date(), userId, questionId, savedAnswer, isCorrect]);
    } finally {
      lock.releaseLock();
    }
  }
}

function resetUserHistory(providedId, target) {
  const userId = \_resolveUserId(providedId);
  const lock = LockService.getScriptLock();

  
  if (lock.tryLock(10000)) {
    try {
      const ss = SpreadsheetApp.openById(getSpreadsheetId());
      const sheet = \_getSheetByKeyStrict(ss, SHEET_KEYS.HISTORY);
      if (!sheet) throw new Error("History sheet not found");

      
      const data = sheet.getDataRange().getValues();
      if (data.length <= 1) return;

      
      const header = data[0];
      const rows = data.slice(1);
      let newRows;

      if (target === 'all') {
        newRows = rows.filter(row => String(row[1]) !== String(userId));
      } else {
        const [examName, examGrade] = target.split(' ');

        
        const exams = \_getCachedSheetData(SHEET_KEYS.EXAMS);
        const instances = \_getCachedSheetData(SHEET_KEYS.INSTANCES);
        const questions = \_getCachedSheetData(SHEET_KEYS.QUESTIONS);

        
        const targetExamIds = new Set();
        exams.forEach(e => {
           const name = e.exam_name || e.name;
           const grade = e.exam_grade || e.grade;
           if (name === examName && (!examGrade || grade === examGrade)) {
               targetExamIds.add(String(e.exam_id || e.id));
           }
        });

        
        const targetInstIds = new Set();
        instances.forEach(i => {
           if (targetExamIds.has(String(i.exam_id))) targetInstIds.add(String(i.instance_id));
        });

        
        const targetQIds = new Set();
        questions.forEach(q => {
           if (targetInstIds.has(String(q.instance_id))) targetQIds.add(String(q.question_id));
        });

        newRows = rows.filter(row => {
          const rUser = String(row[1]);
          const rQId = String(row[2]);
          if (rUser === String(userId) && targetQIds.has(rQId)) return false;
          return true;
        });
      }

      
      sheet.clearContents();
      sheet.appendRow(header);
      if (newRows.length > 0) {
        sheet.getRange(2, 1, newRows.length, newRows[0].length).setValues(newRows);
      }
    } catch(e) {
      console.error(e);
      throw e;
    } finally {
      lock.releaseLock();
    }
  }
}

function clearServerCache() {
  const cache = CacheService.getScriptCache();
}

function \_resolveUserId(providedId) {
  try {
    const email = Session.getActiveUser().getEmail();
    if (email && email.trim() !== '') return email;
  } catch (e) {}
  return providedId || 'guest_user';
}

function \_getSheetByKeyStrict(ss, keyName) {
  const sheets = ss.getSheets();
  const exact = ss.getSheetByName(keyName);
  if (exact) return exact;

  const normalize = (s) => s.toLowerCase().replace(/[\s_\-]+/g, '');
  const target = normalize(keyName);

  for (const s of sheets) {
    const name = normalize(s.getName());
    if (name === target) return s;
  }
  return null;
}

function \_getUserFlagSet(flagData, userId) {
  const set = new Set();
  flagData.forEach(f => {
    if (String(f.user_id) === String(userId)) set.add(String(f.question_id));
  });
  return set;
}

function _readSheetByKey(ss, sheetKey) {
  const sheet = \_getSheetByKeyStrict(ss, sheetKey);
  if (!sheet) return [];
  const values = sheet.getDataRange().getValues();
  if (values.length < 2) return [];
  const headers = values[0];
  return values.slice(1).map(row => {
    const obj = {};
    headers.forEach((h, i) => {
      const key = String(h).trim().toLowerCase().replace(/[\s\-]+/g, '_');
      if (key) {
        const val = row[i];
        obj[key] = (typeof val === 'string') ? val.trim() : val;
      }
    });
    return obj;
  });
}

function _getCachedSheetData(sheetKey) {
  const cache = CacheService.getScriptCache();
  const cacheKey = `sheet_${sheetKey}_${DATA_VERSION}`;
  const metaJson = cache.get(cacheKey);

  if (metaJson) {
    try {
      const meta = JSON.parse(metaJson);
      if (meta.chunks > 0) {
        let jsonString = "";
        for (let i = 0; i < meta.chunks; i++) {
          const chunk = cache.get(`${cacheKey}_${i}`);
          if (!chunk) return \_refreshCache(sheetKey, cacheKey);
          jsonString += chunk;
        }
        return JSON.parse(jsonString);
      }
    } catch (e) {
      return \_refreshCache(sheetKey, cacheKey);
    }
  }
  return \_refreshCache(sheetKey, cacheKey);
}

function _refreshCache(sheetKey, cacheKey) {
  const ss = SpreadsheetApp.openById(getSpreadsheetId());
  const data = \_readSheetByKey(ss, sheetKey);
  try {
    const jsonString = JSON.stringify(data);
    const cache = CacheService.getScriptCache();
    const CHUNK_SIZE = 90000;
    const chunks = Math.ceil(jsonString.length / CHUNK_SIZE);
    for (let i = 0; i < chunks; i++) {
      cache.put(`${cacheKey}_${i}`, jsonString.substring(i _ CHUNK_SIZE, (i + 1) _ CHUNK_SIZE), 21600);
    }
    cache.put(cacheKey, JSON.stringify({ chunks: chunks, timestamp: new Date().getTime() }), 21600);
  } catch (e) {
    console.error("Cache Error", e);
  }
  return data;
}

function \_filterQuestions(questions, instances, exams, filters) {
  if (!filters || Object.keys(filters).length === 0) return questions;

  
  const validExamIds = new Set();
  exams.forEach(e => {
    let isMatch = true;
    const name = e.exam_name || e.name;
    const grade = e.exam_grade || e.grade;
    const id = String(e.exam_id || e.id).trim();

    
    if (filters.examName && String(name).trim() !== String(filters.examName).trim()) isMatch = false;
    if (filters.grade && String(grade).trim() !== String(filters.grade).trim()) isMatch = false;

    
    if (isMatch) validExamIds.add(id);
  });

  const validInstanceIds = new Set();
  instances.forEach(inst => {
    let isMatch = true;
    if (!validExamIds.has(String(inst.exam_id).trim())) isMatch = false;
    if (filters.types && filters.types.length > 0 && !filters.types.includes('all')) {
      if (!filters.types.includes(inst.exam_type)) isMatch = false;
    }
    if (isMatch) validInstanceIds.add(String(inst.instance_id).trim());
  });

  return questions.filter(q => validInstanceIds.has(String(q.instance_id).trim()));
}

function getUserSettings(providedId) {
  const userId = \_resolveUserId(providedId);
  const ss = SpreadsheetApp.openById(getSpreadsheetId());
  const sheet = \_getSheetByKeyStrict(ss, SHEET_KEYS.SETTINGS);
  if (!sheet) return null;

  
  const data = sheet.getDataRange().getValues();
  let uIdx = -1, sIdx = -1;
  if(data.length > 0) {
    const h = data[0];
    for(let i=0; i<h.length; i++) {
      const key = String(h[i]).toLowerCase();
      if(key.includes('user_id')) uIdx = i;
      if(key.includes('settings')) sIdx = i;
    }
  }
  if (uIdx === -1 || sIdx === -1) return null;

  for (let i = 1; i < data.length; i++) {
    if (String(data[i][uIdx]) === String(userId)) {
      try { return JSON.parse(data[i][sIdx]); } catch(e) { return null; }
    }
  }
  return null;
}

function saveUserSettings(providedId, settingsJson) {
  const userId = \_resolveUserId(providedId);
  const lock = LockService.getScriptLock();
  if (lock.tryLock(3000)) {
    try {
      const ss = SpreadsheetApp.openById(getSpreadsheetId());
      let sheet = \_getSheetByKeyStrict(ss, SHEET_KEYS.SETTINGS);
      if (!sheet) {
        sheet = ss.insertSheet(SHEET_KEYS.SETTINGS);
        sheet.appendRow(["user_id", "settings_json", "last_updated"]);
      }

      
      const data = sheet.getDataRange().getValues();
      let rowIdx = -1;
      let uIdx = 0, sIdx = 1, dIdx = 2;
      if(data.length > 0) {
         const h = data[0];
         for(let i=0; i<h.length; i++) {
           const key = String(h[i]).toLowerCase();
           if(key.includes('user_id')) uIdx = i;
           if(key.includes('settings')) sIdx = i;
           if(key.includes('updated')) dIdx = i;
         }
      }

      for (let i = 1; i < data.length; i++) {
        if (String(data[i][uIdx]) === String(userId)) {
          rowIdx = i + 1;
          break;
        }
      }

      
      const ts = new Date();
      if (rowIdx > 0) {
        sheet.getRange(rowIdx, sIdx + 1).setValue(settingsJson);
        sheet.getRange(rowIdx, dIdx + 1).setValue(ts);
      } else {
        sheet.appendRow([userId, settingsJson, ts]);
      }
    } finally {
      lock.releaseLock();
    }
  }
}

# 既存の index.html

<!DOCTYPE html>
<html lang="ja">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, viewport-fit=cover">
  <title>BizLaw Master</title>
  <script src="https://cdn.tailwindcss.com"></script>
  <script>
    tailwind.config = {
      darkMode: 'class',
      theme: {
        extend: {
          colors: {
            brand: { bg: { light: '#f8fafc', dark: '#020617' }, text: { main: { light: '#0f172a', dark: '#e2e8f0' } } },
            primary: { light: '#0f766e', DEFAULT: '#0d9488', dark: '#14b8a6' },
          },
          fontFamily: { sans: ['"Inter"', '"Noto Sans JP"', 'sans-serif'] },
          animation: { 'fade-in': 'fadeIn 0.3s ease-out', 'pop': 'pop 0.3s cubic-bezier(0.175, 0.885, 0.32, 1.275)' },
          keyframes: {
            fadeIn: { '0%': { opacity: '0' }, '100%': { opacity: '1' } },
            pop: { '0%': { transform: 'scale(0.95)' }, '50%': { transform: 'scale(1.05)' }, '100%': { transform: 'scale(1)' } }
          }
        }
      }
    }
  </script>
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=Noto+Sans+JP:wght@400;500;700&display=swap" rel="stylesheet">
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.css">
  <script src="https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.js"></script>
  <script src="https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/contrib/auto-render.min.js"></script>

  <script> const SERVER_INITIAL_SETTINGS = null; </script>

  <style>
    :root { --safe-top: env(safe-area-inset-top, 0px); --safe-bottom: env(safe-area-inset-bottom, 0px); --app-font-size: 16px; }
    body { font-family: 'Inter', 'Noto Sans JP', sans-serif; padding-top: var(--safe-top); padding-bottom: calc(var(--safe-bottom) + 70px); overscroll-behavior-y: none; font-size: var(--app-font-size); }
    /_ Select Icon _/
    select { background-image: url("data:image/svg+xml,%3csvg xmlns='http://www.w3.org/2000/svg' fill='none' viewBox='0 0 20 20'%3e%3cpath stroke='%236b7280' stroke-linecap='round' stroke-linejoin='round' stroke-width='1.5' d='M6 8l4 4 4-4'/%3e%3c/svg%3e"); background-position: right 0.5rem center; background-repeat: no-repeat; background-size: 1.5em 1.5em; padding-right: 2.5rem; -webkit-appearance: none; appearance: none; }
    input[type=range] { -webkit-appearance: none; width: 100%; background: transparent; }
    input[type=range]::-webkit-slider-thumb { -webkit-appearance: none; height: 20px; width: 20px; border-radius: 50%; background: #0d9488; cursor: pointer; margin-top: -8px; box-shadow: 0 1px 3px rgba(0,0,0,0.3); }
    input[type=range]::-webkit-slider-runnable-track { width: 100%; height: 4px; cursor: pointer; background: #e2e8f0; border-radius: 2px; }
    .dark input[type=range]::-webkit-slider-runnable-track { background: #475569; }
    .spinner { border: 3px solid rgba(255, 255, 255, 0.3); border-radius: 50%; border-top: 3px solid currentColor; width: 24px; height: 24px; animation: spin 1s linear infinite; }
    @keyframes spin { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }
    .progress-bar-container { background-color: #e5e7eb; border-radius: 9999px; overflow: hidden; }
    .dark .progress-bar-container { background-color: #374151; }
    .progress-bar-fill { background-color: #d97706; height: 100%; transition: width 0.3s ease; }
    .dark .progress-bar-fill { background-color: #fbbf24; }
    .result-score-circle { width: 160px; height: 160px; border-radius: 50%; background: conic-gradient(#10b981 0% 0%, #e5e7eb 0% 100%); display: flex; align-items: center; justify-content: center; position: relative; margin: 0 auto; box-shadow: 0 4px 12px rgba(0,0,0,0.1); transition: background 1s ease-out; }
    .result-score-circle::before { content: ""; position: absolute; width: 130px; height: 130px; background-color: white; border-radius: 50%; }
    .dark .result-score-circle::before { background-color: #1f2937; }
    .accordion-content { transition: max-height 0.3s ease-out, opacity 0.3s ease-out; max-height: 0; opacity: 0; overflow: hidden; }
    .accordion-content.open { max-height: 800px; opacity: 1; }
    .custom-scrollbar::-webkit-scrollbar { width: 6px; }
    .custom-scrollbar::-webkit-scrollbar-track { background: transparent; }
    .custom-scrollbar::-webkit-scrollbar-thumb { background-color: rgba(156, 163, 175, 0.5); border-radius: 20px; }
    .nav-item.active { color: #0d9488; }
    .dark .nav-item.active { color: #2dd4bf; }
    .nav-item.active svg { stroke: #0d9488; }
    .dark .nav-item.active svg { stroke: #2dd4bf; }
    .choice-eliminated { opacity: 0.4; filter: grayscale(100%); text-decoration: line-through; }
    .calendar-grid { display: grid; grid-template-columns: repeat(7, 1fr); gap: 3px; }
    .calendar-day { aspect-ratio: 1; border-radius: 4px; font-size: 10px; display: flex; align-items: center; justify-content: center; position: relative; }
    .heat-l1 { background-color: #ccfbf1 !important; color: #0f766e !important; } .heat-l2 { background-color: #99f6e4 !important; color: #0f766e !important; } .heat-l3 { background-color: #5eead4 !important; color: #0f766e !important; } .heat-l4 { background-color: #2dd4bf !important; color: #fff !important; } .heat-l5 { background-color: #0d9488 !important; color: #fff !important; }
    .dark .heat-l1 { background-color: #134e4a !important; color: #99f6e4 !important; } .dark .heat-l2 { background-color: #115e59 !important; color: #99f6e4 !important; } .dark .heat-l3 { background-color: #0f766e !important; color: #fff !important; } .dark .heat-l4 { background-color: #0d9488 !important; color: #fff !important; } .dark .heat-l5 { background-color: #14b8a6 !important; color: #000 !important; }
    #quiz-explanation-text, .choice-explanation { white-space: pre-wrap; }
  </style>

</head>
<body class="antialiased min-h-screen flex flex-col bg-brand-bg-light dark:bg-brand-bg-dark text-brand-text-main-light dark:text-brand-text-main-dark transition-colors duration-300" id="app-body">

  <header class="sticky top-0 z-50 bg-white/90 dark:bg-slate-900/90 border-b border-gray-200 dark:border-gray-700 shadow-sm backdrop-blur-sm transition-colors">
    <div class="max-w-5xl mx-auto px-4 h-14 flex items-center justify-between gap-3">
      <div class="flex flex-wrap items-baseline gap-x-3 gap-y-0 min-w-0 flex-1 overflow-hidden" onclick="showPage('home-page')">
        <h1 id="header-logo" class="text-lg font-bold tracking-tight text-slate-800 dark:text-slate-100 truncate cursor-pointer flex-shrink-0 flex items-center gap-1.5">
            <svg class="w-5 h-5 text-teal-600 dark:text-teal-400 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>
            BizLaw Master
        </h1>
        <div id="header-context-info" class="hidden text-[11px] font-bold text-teal-700 dark:text-teal-400 truncate leading-none"></div>
      </div>
      <div class="flex items-center gap-1 flex-shrink-0">
         <button onclick="toggleSettingsModal()" class="p-2 rounded-full hover:bg-gray-100 dark:hover:bg-gray-800 transition-colors text-gray-500 dark:text-gray-400 flex-shrink-0">
             <svg class="w-6 h-6 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"></path><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"></path></svg>
         </button>
      </div>
    </div>
  </header>

  <main class="flex-grow container max-w-5xl mx-auto p-4">
    <div id="loading-overlay" class="fixed inset-0 bg-black bg-opacity-50 z-50 flex items-center justify-center hidden backdrop-blur-sm">
      <div class="bg-white dark:bg-gray-800 p-6 rounded-xl shadow-xl flex flex-col items-center animate-pop">
        <div class="spinner text-teal-600 mb-3"></div>
        <p id="loading-message" class="text-sm font-medium">Loading...</p>
      </div>
    </div>
    <div id="toast-container" class="fixed bottom-4 right-4 z-50 pointer-events-none space-y-2"></div>

    <!-- Global Filter (Common) -->
    <div id="global-filter-section" class="max-w-3xl mx-auto bg-white dark:bg-slate-800 p-5 rounded-xl border border-gray-200 dark:border-gray-700 shadow-sm transition-colors space-y-4 mb-6">
        <h3 class="font-bold text-sm flex items-center gap-2 text-teal-700 dark:text-teal-400">
          <svg class="w-5 h-5 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-3 7h3m-3 4h3m-6-4h.01M9 16h.01"></path></svg>
          学習対象を選択
        </h3>
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
          <div>
            <label class="text-xs text-slate-500 dark:text-slate-400 block mb-1 font-medium">試験名</label>
            <select id="global-exam-select" class="w-full px-3 py-2.5 rounded-lg border border-gray-200 dark:border-gray-600 bg-white dark:bg-slate-800 dark:text-slate-200 text-sm focus:ring-2 focus:ring-teal-500 focus:outline-none min-h-[44px]" onchange="onExamSelectChange()">
              <option value="" disabled selected>読み込み中...</option>
            </select>
          </div>
          <div>
            <label class="text-xs text-slate-500 dark:text-slate-400 block mb-1 font-medium">級・レベル</label>
            <select id="global-grade-select" class="w-full px-3 py-2.5 rounded-lg border border-gray-200 dark:border-gray-600 bg-white dark:bg-slate-800 dark:text-slate-200 text-sm focus:ring-2 focus:ring-teal-500 focus:outline-none min-h-[44px]" onchange="updateGlobalFiltersState()">
              <!-- Options -->
            </select>
          </div>
        </div>
        <div>
            <label class="text-xs text-slate-500 dark:text-slate-400 block mb-2 font-medium">試験タイプ (複数選択可)</label>
            <div id="global-type-buttons" class="flex flex-wrap gap-2 min-h-[40px]"><span class="text-xs text-gray-400 py-2 pl-1">試験名を選択すると表示されます</span></div>
        </div>
    </div>

    <!-- PAGE: Home -->
    <div id="home-page" class="page-section space-y-6 animate-fade-in max-w-3xl mx-auto">

      
      <!-- Resume Card -->
      <div id="resume-card-container" class="hidden">
          <div class="bg-gradient-to-r from-indigo-500 to-purple-600 rounded-xl p-5 shadow-lg text-white relative overflow-hidden cursor-pointer transform hover:scale-[1.01] transition-transform" onclick="resumeLearning()">
              <div class="absolute top-0 right-0 p-3 opacity-20"><svg class="w-16 h-16 flex-shrink-0" fill="currentColor" viewBox="0 0 24 24"><path d="M13 10V3L4 14h7v7l9-11h-7z"></path></svg></div>
              <div class="flex justify-between items-start z-10 relative">
                  <div>
                      <p class="text-xs font-bold opacity-80 mb-1">前回の続きから</p>
                      <p id="resume-time-text" class="text-[10px] opacity-70 font-mono mb-1"></p>
                  </div>
                  <button onclick="event.stopPropagation(); handleResumeDelete();" class="p-1.5 bg-white/20 hover:bg-white/30 rounded-full transition-colors text-white z-20">
                      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"></path></svg>
                  </button>
              </div>
              <h3 class="text-lg font-bold mb-1 flex items-center gap-2 relative z-10">学習を再開する</h3>
              <p id="resume-info-text" class="text-sm font-medium opacity-95 mb-1 line-clamp-1 relative z-10">読み込み中...</p>
          </div>
      </div>

      <!-- Smart Learning -->
      <div class="bg-white dark:bg-slate-800 p-6 rounded-xl shadow-sm border border-gray-200 dark:border-gray-700 relative overflow-hidden group cursor-pointer hover:shadow-md transition-all" onclick="startSmartQuiz()">
        <div class="absolute top-0 right-0 p-4 opacity-10 group-hover:opacity-20 transition-opacity"><svg class="w-24 h-24 text-teal-600 flex-shrink-0" fill="currentColor" viewBox="0 0 24 24"><path d="M12 2L2 7l10 5 10-5-10-5zm0 9l2.5-1.25L12 8.5l-2.5 1.25L12 11zm0 2.5l-5-2.5-5 2.5L12 22l10-8.5-5-2.5-5 2.5z"></path></svg></div>
        <h3 class="text-xl font-bold text-teal-700 dark:text-teal-400 mb-2 flex items-center gap-2"><svg class="w-5 h-5 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"></path></svg>スマート学習（おまかせ）</h3>
        <p class="text-slate-500 dark:text-slate-400 text-sm mb-4">AIが忘却曲線と苦手に合わせて、上記で選択した範囲から最適な問題を厳選します。</p>
      </div>

      <!-- Flagged Questions -->
      <div class="bg-white dark:bg-slate-800 p-5 rounded-xl shadow-sm border border-amber-200 dark:border-amber-800/50 hover:border-amber-400 transition-colors cursor-pointer group" onclick="startFlaggedQuiz()">
        <div class="flex items-center justify-between">
            <h3 class="text-lg font-bold text-amber-600 dark:text-amber-500 flex items-center gap-2">
                <svg class="w-6 h-6 fill-current" viewBox="0 0 24 24"><path d="M5 3v18l7-5 7 5V3z"></path></svg>
                あとで解く（フラグ）
            </h3>
        </div>
        <p class="text-xs text-slate-500 dark:text-slate-400 mt-2">フラグを付けた問題のみを出題します。</p>
      </div>

      <!-- Navigation Cards -->
      <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
        <div class="bg-white dark:bg-slate-800 p-5 rounded-xl shadow-sm border border-gray-200 dark:border-gray-700 hover:border-teal-500 transition-colors cursor-pointer" onclick="showPage('question-list-page')">
          <h3 class="font-bold mb-1 flex items-center gap-2 text-slate-800 dark:text-slate-100"><svg class="w-5 h-5 text-gray-500 dark:text-gray-400 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 10h16M4 14h16M4 18h16"></path></svg>問題一覧から選ぶ</h3>
          <p class="text-xs text-slate-500 dark:text-slate-400">選択範囲の問題を一覧表示</p>
        </div>
        <div class="bg-white dark:bg-slate-800 p-5 rounded-xl shadow-sm border border-gray-200 dark:border-gray-700 hover:border-teal-500 transition-colors cursor-pointer" onclick="showPage('stats-page')">
          <h3 class="font-bold mb-1 flex items-center gap-2 text-slate-800 dark:text-slate-100"><svg class="w-5 h-5 text-blue-500 dark:text-blue-400 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"></path></svg>学習データ分析</h3>
          <p class="text-xs text-slate-500 dark:text-slate-400">進捗状況と正答率の推移を確認</p>
        </div>
      </div>
    </div>

    <!-- PAGE: Question List -->
    <div id="question-list-page" class="page-section hidden max-w-3xl mx-auto relative pb-24">
      <div class="flex items-center justify-between mb-4 sticky top-14 bg-brand-bg-light dark:bg-brand-bg-dark z-30 py-2">
        <h2 class="text-xl font-bold flex items-center gap-2">問題一覧</h2>
        <div class="text-xs font-mono text-gray-500 bg-white dark:bg-slate-800 px-3 py-1 rounded-full border border-gray-200 dark:border-gray-700 shadow-sm"><span id="list-count" class="font-bold text-teal-600 text-sm">0</span> 件</div>
      </div>

      
      <div class="bg-white dark:bg-slate-800 p-5 rounded-xl border border-gray-200 dark:border-gray-700 shadow-sm mb-4 space-y-5">
        <div>
           <div class="flex justify-end items-center mb-2">
               <div class="relative">
                   <select id="list-sort-select" onchange="renderQuestionList()" class="appearance-none bg-gray-50 dark:bg-slate-700 border border-gray-200 dark:border-gray-600 text-gray-600 dark:text-gray-300 py-1.5 pl-3 pr-8 rounded text-xs font-bold focus:outline-none focus:border-teal-500">
                       <option value="default" selected>並び替え: 標準 (分類順)</option>
                       <option value="accuracy_asc">正答率: 低い順</option>
                       <option value="accuracy_desc">正答率: 高い順</option>
                       <option value="newest">実施回: 新しい順</option>
                   </select>
               </div>
           </div>
           <label class="block text-xs font-bold text-slate-500 dark:text-slate-400 mb-1.5">キーワード検索</label>
           <input type="text" id="filter-keyword" placeholder="用語、分類名..." class="w-full px-3 py-2.5 rounded-lg border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-700 text-sm focus:ring-2 focus:ring-teal-500 focus:outline-none transition-shadow" oninput="renderQuestionList()">
        </div>

        <div>
            <label class="block text-xs font-bold text-slate-500 dark:text-slate-400 mb-2">ステータス絞り込み</label>
            <div id="filter-status-buttons" class="flex flex-wrap gap-2"></div>
        </div>

        <div>
           <div class="flex p-1 bg-gray-100 dark:bg-gray-700/50 rounded-lg">
               <label class="flex-1 cursor-pointer">
                   <input type="radio" name="list-filter-mode" value="exam" class="peer sr-only" onchange="toggleFilterMode()">
                   <div class="text-center py-2 text-xs font-bold text-gray-500 rounded-md transition-all peer-checked:bg-white peer-checked:text-teal-600 peer-checked:shadow-sm dark:peer-checked:bg-slate-700 dark:peer-checked:text-teal-400">試験回別</div>
               </label>
               <label class="flex-1 cursor-pointer">
                   <input type="radio" name="list-filter-mode" value="category" class="peer sr-only" checked onchange="toggleFilterMode()">
                   <div class="text-center py-2 text-xs font-bold text-gray-500 rounded-md transition-all peer-checked:bg-white peer-checked:text-teal-600 peer-checked:shadow-sm dark:peer-checked:bg-slate-700 dark:peer-checked:text-teal-400">分野別</div>
               </label>
           </div>
        </div>

        <div id="filter-exam-area" class="hidden animate-fade-in">
           <label class="block text-xs font-bold text-slate-500 dark:text-slate-400 mb-2">試験回 <span class="font-normal text-gray-400">(複数選択可)</span></label>
           <div id="filter-exam-buttons" class="flex flex-wrap gap-2"></div>
        </div>

        <div id="filter-category-area" class="space-y-5 animate-fade-in">
            <div>
                <label class="block text-xs font-bold text-slate-500 dark:text-slate-400 mb-2">大分類 <span class="font-normal text-gray-400">(複数選択可)</span></label>
                <div id="filter-cat1-buttons" class="flex flex-wrap gap-2"></div>
            </div>
            <div>
                <label class="block text-xs font-bold text-slate-500 dark:text-slate-400 mb-3">中分類 <span class="font-normal text-gray-400">(大分類を選択すると表示されます)</span></label>
                <div id="filter-cat2-grouped-area" class="space-y-4">
                    <div class="text-xs text-gray-400 text-center py-2">大分類を選択してください</div>
                </div>
            </div>
            <div>
                <label class="block text-xs font-bold text-slate-500 dark:text-slate-400 mb-3">小分類 <span class="font-normal text-gray-400">(中分類を選択すると表示されます)</span></label>
                <div id="filter-cat3-grouped-area" class="space-y-4">
                    <div class="text-xs text-gray-400 text-center py-2">中分類を選択してください</div>
                </div>
            </div>
        </div>
      </div>
      <div id="question-list-container" class="space-y-3"></div>

      
      <div class="fixed bottom-20 right-4 left-4 z-40 flex justify-center pointer-events-none">
        <button onclick="startListQuiz()" class="pointer-events-auto shadow-lg bg-teal-600 hover:bg-teal-700 text-white font-bold py-3 px-6 rounded-full flex items-center gap-2 transition-transform active:scale-95 w-full max-w-xs justify-center ring-4 ring-white dark:ring-slate-900">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14.752 11.168l-3.197-2.132A1 1 0 0010 9.87v4.263a1 1 0 001.555.832l3.197-2.132a1 1 0 000-1.664z"></path><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>
            表示中の問題で出題開始
        </button>
      </div>
    </div>

    <!-- PAGE: Stats -->
    <div id="stats-page" class="page-section hidden max-w-3xl mx-auto">
        <div class="flex items-center justify-between mb-4"><h2 class="text-xl font-bold">学習データ分析</h2></div>
        <div class="space-y-6 pb-20">
            <div class="bg-white dark:bg-slate-800 p-5 rounded-xl border border-gray-200 dark:border-gray-700 shadow-sm">
                <h3 class="font-bold text-sm mb-4 flex items-center gap-2"><svg class="w-4 h-4 text-gray-500 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"></path></svg>学習履歴 (直近2ヶ月)</h3>
                <div id="stats-calendar-container" class="grid grid-cols-1 sm:grid-cols-2 gap-6"></div>
            </div>
            <!-- Other Stats Components -->
            <div class="grid grid-cols-3 sm:grid-cols-5 gap-2 sm:gap-3">
                <div class="bg-white dark:bg-slate-800 p-3 rounded-xl border border-gray-200 dark:border-gray-700 shadow-sm text-center"><div class="text-[10px] text-sub mb-1">学習日数</div><div class="text-base sm:text-lg font-bold text-teal-600 dark:text-teal-400" id="stats-total-days">0<span class="text-[10px] text-gray-500 ml-1">日</span></div></div>
                <div class="bg-white dark:bg-slate-800 p-3 rounded-xl border border-gray-200 dark:border-gray-700 shadow-sm text-center"><div class="text-[10px] text-sub mb-1">学習時間</div><div class="text-base sm:text-lg font-bold text-teal-600 dark:text-teal-400" id="stats-total-time">0<span class="text-[10px] text-gray-500 ml-1">分</span></div></div>
                <div class="bg-white dark:bg-slate-800 p-3 rounded-xl border border-gray-200 dark:border-gray-700 shadow-sm text-center"><div class="text-[10px] text-sub mb-1">解答数</div><div class="text-sm sm:text-lg font-bold text-teal-600 dark:text-teal-400 flex items-baseline justify-center gap-0.5"><span id="stats-total-count">0</span><span class="text-[10px] text-gray-400">/</span><span id="stats-all-questions" class="text-[10px] text-gray-400">0</span></div></div>
                <div class="bg-white dark:bg-slate-800 p-3 rounded-xl border border-gray-200 dark:border-gray-700 shadow-sm text-center"><div class="text-[10px] text-sub mb-1">正答率</div><div class="text-base sm:text-lg font-bold text-teal-600 dark:text-teal-400" id="stats-accuracy">0<span class="text-[10px] text-gray-500 ml-1">%</span></div></div>
                <div class="bg-white dark:bg-slate-800 p-3 rounded-xl border border-gray-200 dark:border-gray-700 shadow-sm text-center"><div class="text-[10px] text-sub mb-1">完了予測</div><div class="text-base sm:text-lg font-bold text-teal-600 dark:text-teal-400" id="stats-prediction">--<span class="text-[10px] text-gray-500 ml-1">日</span></div></div>
            </div>
            <div class="bg-white dark:bg-slate-800 p-5 rounded-xl border border-gray-200 dark:border-gray-700 shadow-sm">
                <h3 class="font-bold text-sm mb-4 flex items-center gap-2"><svg class="w-4 h-4 text-indigo-500 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 3.055A9.001 9.001 0 1020.945 13H11V3.055z"></path><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20.488 9H15V3.512A9.025 9.025 0 0120.488 9z"></path></svg>解答内訳</h3>
                <div class="h-4 w-full rounded-full overflow-hidden flex bg-gray-100 dark:bg-slate-700"><div id="bar-correct" class="h-full bg-teal-500 transition-all duration-500" style="width:0%"></div><div id="bar-incorrect" class="h-full bg-red-500 transition-all duration-500" style="width:0%"></div></div>
                <div class="flex justify-between mt-2 text-xs text-sub">
                    <div class="flex items-center gap-1"><div class="w-2 h-2 rounded-full bg-teal-500"></div>正解: <span id="val-correct" class="font-bold">0</span></div>
                    <div class="flex items-center gap-1"><div class="w-2 h-2 rounded-full bg-red-500"></div>不正解: <span id="val-incorrect" class="font-bold">0</span></div>
                    <div class="flex items-center gap-1"><div class="w-2 h-2 rounded-full bg-gray-200 dark:bg-slate-700 border border-gray-300 dark:border-gray-600"></div>未解答: <span id="val-unanswered" class="font-bold">0</span></div>
                </div>
            </div>
            <div id="stats-analysis-container" class="space-y-4">
                <div class="bg-white dark:bg-slate-800 p-4 rounded-xl border border-gray-200 dark:border-gray-700 shadow-sm">
                    <h3 class="font-bold text-sm mb-3 flex items-center gap-2"><svg class="w-4 h-4 text-gray-500 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"></path></svg>試験タイプ別</h3>
                    <div id="stats-type-list" class="space-y-3"></div>
                </div>
                <div class="bg-white dark:bg-slate-800 p-4 rounded-xl border border-gray-200 dark:border-gray-700 shadow-sm">
                    <h3 class="font-bold text-sm mb-3 flex items-center gap-2"><svg class="w-4 h-4 text-indigo-500 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"></path></svg>分野別 (大分類)</h3>
                    <div id="stats-cat1-list" class="space-y-3"></div>
                </div>
                <div class="bg-white dark:bg-slate-800 p-4 rounded-xl border border-gray-200 dark:border-gray-700 shadow-sm">
                    <h3 class="font-bold text-sm mb-3 flex items-center gap-2"><svg class="w-4 h-4 text-pink-500 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 7h.01M7 3h5c.512 0 1.024.195 1.414.586l7 7a2 2 0 010 2.828l-7 7a2 2 0 01-2.828 0l-7-7A1.994 1.994 0 013 12V7a4 4 0 014-4z"></path></svg>詳細分野 (中分類)</h3>
                    <div id="stats-cat2-list" class="space-y-3"></div>
                </div>
            </div>
        </div>
    </div>

    <!-- PAGE: Quiz -->
    <div id="quiz-page" class="page-section hidden h-full flex flex-col">
        <div class="flex items-center justify-between mb-4 text-xs font-mono text-sub px-1">
            <div><span id="current-question-num" class="text-lg font-bold text-teal-600 dark:text-teal-400">1</span> / <span id="total-question-num">10</span></div>
            <div id="timer-display" class="bg-gray-100 dark:bg-slate-700 px-2 py-1 rounded transition-colors">00:00</div>
        </div>

        
        <div class="progress-bar-container h-1.5 mb-6"><div id="quiz-progress-bar" class="progress-bar-fill" style="width: 0%"></div></div>

        
        <div class="grid grid-cols-1 lg:grid-cols-12 gap-6 h-full items-start flex-grow pb-32">
            <!-- Scenario Section -->
            <div id="quiz-scenario-wrapper" class="hidden lg:block max-lg:hidden lg:col-span-5 lg:sticky lg:top-24 bg-white dark:bg-slate-800 border border-gray-200 dark:border-gray-700 rounded-xl shadow-sm overflow-hidden max-h-[80vh] flex flex-col">
                <div class="p-3 border-b border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-slate-900 font-bold text-sm flex items-center gap-2">大問・条件 <span id="quiz-scenario-no-desktop" class="text-xs bg-gray-200 dark:bg-gray-700 px-1.5 py-0.5 rounded ml-2"></span></div>
                <div id="quiz-scenario-text-desktop" class="p-4 text-sm leading-relaxed overflow-y-auto custom-scrollbar text-sub"></div>
            </div>
            <!-- Mobile Accordion -->
            <div id="quiz-scenario-accordion-wrapper" class="lg:hidden col-span-1 mb-4 hidden"><div class="bg-teal-50 dark:bg-slate-800 border border-teal-100 dark:border-gray-700 rounded-lg overflow-hidden"><button id="scenario-toggle-btn" class="w-full px-4 py-3 flex items-center justify-between text-left" onclick="toggleScenario()"><span class="text-sm font-bold text-teal-700 dark:text-teal-400 flex items-center gap-2">大問・条件 <span id="quiz-scenario-no-mobile" class="text-xs bg-white/50 px-1.5 py-0.5 rounded text-teal-800 dark:text-teal-200"></span><span class="text-[10px] font-normal opacity-70">（タップで展開）</span></span></button><div id="quiz-scenario-content" class="accordion-content open border-t border-teal-100 dark:border-gray-700 px-4 bg-white dark:bg-slate-800"><div id="quiz-scenario-text-mobile" class="py-3 text-sm leading-relaxed text-sub"></div></div></div></div>
            <div class="col-span-1 lg:col-span-7 space-y-6">
                <div class="bg-white dark:bg-slate-800 rounded-xl shadow-sm border border-gray-200 dark:border-gray-700 p-5 relative">
                     <div class="flex justify-between items-start mb-3">
                         <div class="flex flex-wrap gap-2 text-[10px]">
                            <span id="quiz-info-edition" class="bg-gray-100 dark:bg-slate-700 text-gray-600 dark:text-gray-300 px-2 py-1 rounded font-bold"></span>
                            <span id="quiz-info-type" class="bg-gray-100 dark:bg-slate-700 text-gray-600 dark:text-gray-300 px-2 py-1 rounded font-bold"></span>
                            <span id="quiz-info-s-no" class="bg-indigo-50 dark:bg-indigo-900/30 text-indigo-600 dark:text-indigo-300 px-2 py-1 rounded font-bold"></span>
                            <span id="quiz-info-q-no" class="bg-teal-50 dark:bg-teal-900/30 text-teal-600 dark:text-teal-300 px-2 py-1 rounded font-bold"></span>
                         </div>
                     </div>
                     <div class="flex flex-wrap gap-1.5 text-xs text-slate-500 dark:text-slate-400 mb-4"><span id="quiz-info-cat1" class="font-bold text-slate-700 dark:text-slate-300"></span><span class="text-gray-300">/</span><span id="quiz-info-cat2"></span><span class="text-gray-300">/</span><span id="quiz-info-cat3"></span></div>
                    <div class="flex items-center gap-1" id="quiz-history-dots" title="直近履歴"></div>
                    <div id="quiz-question-text" class="text-lg font-medium leading-relaxed mt-4"></div>
                    <div id="quiz-image-container" class="hidden mt-4 mb-4 flex justify-center"><img id="quiz-question-image" src="" class="max-w-full h-auto rounded-lg border border-gray-200 dark:border-gray-600 shadow-sm"></div>
                </div>
                <div id="quiz-choices-container" class="space-y-3"></div>
                <div id="quiz-explanation-container" class="hidden animate-fade-in">
                    <div class="bg-white dark:bg-slate-800 rounded-xl border-l-4 border-gray-200 dark:border-gray-600 shadow-sm p-5 relative overflow-hidden">
                        <div id="explanation-status-bar" class="absolute top-0 left-0 w-1 h-full bg-gray-300 dark:bg-gray-600"></div>
                        <h4 class="font-bold text-lg mb-2 flex items-center gap-2">解説</h4>
                        <div id="quiz-correct-answer-display" class="mb-3 p-3 bg-gray-50 dark:bg-slate-900 rounded text-sm font-bold"></div>
                        <div id="quiz-explanation-text" class="text-sm leading-relaxed space-y-2 text-sub mb-6"></div>
                    </div>
                </div>
            </div>
        </div>
        <div class="fixed bottom-0 left-0 right-0 bg-white dark:bg-slate-900 border-t border-gray-200 dark:border-gray-800 p-3 z-50 safe-area-pb shadow-[0_-2px_10px_rgba(0,0,0,0.05)]">
            <div class="max-w-5xl mx-auto flex justify-between items-center gap-3 h-12" id="quiz-footer-actions"></div>
        </div>
    </div>

    <!-- PAGE: Result -->
    <div id="result-page" class="page-section hidden max-w-3xl mx-auto text-center space-y-8 py-10">
        <h2 class="text-2xl font-bold">結果発表</h2>
        <div class="result-score-circle">
            <span id="result-score-text" class="text-4xl font-bold text-teal-600 relative z-10"></span>
        </div>
        <div id="result-list-container" class="text-left space-y-3"></div>
        <div class="flex gap-4 justify-center">
            <button onclick="showPage('home-page')" class="px-6 py-3 rounded-full bg-gray-100 dark:bg-slate-700 font-bold hover:bg-gray-200 dark:hover:bg-slate-600">ホームへ</button>
            <button onclick="handleRetry()" class="px-6 py-3 rounded-full bg-teal-600 text-white font-bold hover:bg-teal-700 shadow-lg">もう一度解く</button>
        </div>
    </div>

    <!-- MODAL: Settings -->
    <div id="settings-modal" class="fixed inset-0 z-[100] hidden" aria-labelledby="modal-title" role="dialog" aria-modal="true">
        <div class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity backdrop-blur-sm" onclick="toggleSettingsModal()"></div>
        <div class="fixed inset-0 z-10 w-screen overflow-y-auto">
            <div class="flex min-h-full items-center justify-center p-4 text-center sm:p-0">
                <div class="relative transform overflow-hidden rounded-lg bg-white dark:bg-slate-900 text-left shadow-xl transition-all sm:my-8 sm:w-full sm:max-w-lg border border-gray-200 dark:border-gray-700">
                    <div class="bg-white dark:bg-slate-900 px-4 pb-4 pt-5 sm:p-6 sm:pb-4">
                         <div class="flex justify-between items-center mb-5">
                            <h3 class="text-xl font-bold text-slate-800 dark:text-gray-100" id="modal-title">設定</h3>
                            <button onclick="toggleSettingsModal()" class="text-gray-400 hover:text-gray-500 focus:outline-none">
                                <svg class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" /></svg>
                            </button>
                        </div>

                        
                        <div class="space-y-6">
                            <!-- Account -->
                            <div class="bg-gray-50 dark:bg-slate-800/50 p-4 rounded-xl border border-gray-100 dark:border-gray-700">
                                <h3 class="text-xs font-bold text-gray-400 uppercase tracking-wider mb-3">アカウント</h3>
                                <div class="flex items-center gap-3">
                                    <div class="w-8 h-8 rounded-full bg-teal-100 dark:bg-teal-900/30 flex items-center justify-center text-teal-600 dark:text-teal-400 font-bold"><svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"></path></svg></div>
                                    <div class="font-bold text-sm text-slate-700 dark:text-slate-200" id="setting-account-id">guest_user</div>
                                </div>
                                <div class="mt-3 text-right">
                                    <a href="https://accounts.google.com/Logout" target="_top" class="text-xs text-teal-600 dark:text-teal-400 font-bold hover:underline">ログアウト / 切替</a>
                                </div>
                            </div>

                            
                            <!-- Display Settings -->
                            <div>
                                <h3 class="text-xs font-bold text-gray-400 uppercase tracking-wider mb-3">表示</h3>
                                <div class="flex items-center justify-between mb-4">
                                    <div class="text-sm font-bold text-gray-700 dark:text-gray-200">ダークモード</div>
                                    <label class="inline-flex items-center cursor-pointer">
                                        <input type="checkbox" id="setting-darkmode-toggle" class="sr-only peer" onchange="toggleDarkMode()">
                                        <div class="relative w-11 h-6 bg-gray-200 peer-focus:outline-none rounded-full peer dark:bg-gray-700 peer-checked:after:translate-x-full rtl:peer-checked:after:-translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:start-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all dark:border-gray-600 peer-checked:bg-teal-600"></div>
                                    </label>
                                </div>
                                <div class="flex items-center justify-between mb-4">
                                    <div class="text-sm font-bold text-gray-700 dark:text-gray-200">タイマー表示</div>
                                    <label class="inline-flex items-center cursor-pointer">
                                        <input type="checkbox" id="setting-timer-toggle" class="sr-only peer" onchange="saveSettings()" checked>
                                        <div class="relative w-11 h-6 bg-gray-200 peer-focus:outline-none rounded-full peer dark:bg-gray-700 peer-checked:after:translate-x-full rtl:peer-checked:after:-translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:start-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all dark:border-gray-600 peer-checked:bg-teal-600"></div>
                                    </label>
                                </div>
                                <div class="mb-2">
                                    <div class="flex items-center justify-between mb-2">
                                        <div class="text-sm font-bold text-gray-700 dark:text-gray-200">文字サイズ</div>
                                        <span id="font-size-value" class="text-sm font-bold text-teal-600 dark:text-teal-400">16px</span>
                                    </div>
                                    <input type="range" id="setting-font-size-slider" min="12" max="20" step="1" value="16" class="w-full h-2 bg-gray-200 rounded-lg appearance-none cursor-pointer dark:bg-gray-700" oninput="updateFontSize(this.value)">
                                </div>
                            </div>

                            <!-- Learning Settings -->
                            <div>
                                <h3 class="text-xs font-bold text-gray-400 uppercase tracking-wider mb-3">学習</h3>
                                <div class="mb-4">
                                    <label class="block text-sm font-bold text-gray-700 dark:text-gray-200 mb-1">おまかせ出題数</label>
                                    <select id="setting-omakase-count" onchange="saveSettings()" class="w-full px-3 py-2 rounded-lg border border-gray-200 dark:border-gray-600 bg-white dark:bg-slate-800 focus:ring-2 focus:ring-teal-500 outline-none text-sm"><option value="5">5問</option><option value="10" selected>10問</option><option value="20">20問</option></select>
                                </div>
                                <div class="mb-2">
                                    <label class="block text-sm font-bold text-gray-700 dark:text-gray-200 mb-1">解答モード</label>
                                    <select id="setting-answer-mode" onchange="saveSettings()" class="w-full px-3 py-2 rounded-lg border border-gray-200 dark:border-gray-600 bg-white dark:bg-slate-800 focus:ring-2 focus:ring-teal-500 outline-none text-sm"><option value="instant" selected>即時解答</option><option value="elimination">消去法対応</option></select>
                                </div>
                            </div>

                            <!-- Data Mgmt -->
                            <div class="pt-4 border-t border-gray-100 dark:border-gray-700">
                                <h3 class="text-xs font-bold text-red-400 uppercase tracking-wider mb-3">データ管理</h3>
                                <div class="space-y-3">
                                    <select id="setting-reset-target" class="w-full px-3 py-2 rounded-lg border border-red-200 dark:border-red-900/50 bg-white dark:bg-slate-800 text-sm focus:ring-2 focus:ring-red-500 focus:outline-none"><option value="all">すべての学習履歴</option></select>
                                    <button class="w-full py-2 text-red-600 dark:text-red-400 font-bold hover:bg-red-50 dark:hover:bg-red-900/20 rounded-lg transition-colors border border-red-200 dark:border-red-900/50 text-sm" onclick="handleResetHistory()">履歴を削除</button>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>

  </main>

  <nav id="global-nav" class="fixed bottom-0 left-0 right-0 bg-white dark:bg-slate-900 border-t border-gray-200 dark:border-gray-800 pb-[env(safe-area-inset-bottom)] z-50 shadow-[0_-2px_10px_rgba(0,0,0,0.05)]">
    <div class="max-w-5xl mx-auto flex justify-around items-center h-16">
      <button onclick="showPage('home-page')" class="nav-item flex flex-col items-center justify-center w-full h-full text-gray-400 hover:text-teal-600 dark:hover:text-teal-400 transition-colors active" id="nav-home"><svg class="w-6 h-6 mb-1 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6"></path></svg><span class="text-[10px] font-bold tracking-wide">ホーム</span></button>
      <button onclick="showPage('question-list-page')" class="nav-item flex flex-col items-center justify-center w-full h-full text-gray-400 hover:text-teal-600 dark:hover:text-teal-400 transition-colors" id="nav-list"><svg class="w-6 h-6 mb-1 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 10h16M4 14h16M4 18h16"></path></svg><span class="text-[10px] font-bold tracking-wide">一覧</span></button>
      <button onclick="showPage('stats-page')" class="nav-item flex flex-col items-center justify-center w-full h-full text-gray-400 hover:text-teal-600 dark:hover:text-teal-400 transition-colors" id="nav-stats"><svg class="w-6 h-6 mb-1 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"></path></svg><span class="text-[10px] font-bold tracking-wide">分析</span></button>
    </div>
  </nav>

  <script>
    if (typeof google === 'undefined') {
      window.google = { script: { run: { withSuccessHandler: function(s) { this.s=s; return this; }, withFailureHandler: function(f) { this.f=f; return this; }, getUserSettings: function() { setTimeout(()=>this.s({}), 100); }, getInitialData: function() { setTimeout(()=>this.s({instances:[], questionsMeta:[], sortMaster: []}), 500); }, saveUserSettings: function(){}, getSmartQuestions: function(){}, getFlaggedQuestions: function(){}, getQuestionsByIds: function(){}, getQuestionDetail: function(){}, toggleReviewFlag: function(){}, getUserStats: function(){}, saveHistory: function(){}, resetUserHistory: function(){}, reportQuestionIssue: function(){} } } };
    }

    const quizState = {
      userId: 'guest_user',
      questions: [],
      currentIndex: 0,
      userAnswers: [],
      sessionResults: [],
      history: {}, 
      flags: new Set(),
      settings: { darkMode: false, omakaseCount: 10, fontSize: 16, resumeData: null, answerMode: 'instant', showTimer: true, lastFilter: null },
      currentSet: [],
      masterData: { exams: [], categories: [], instances: [], questionsMeta: [], questions: [], sortMaster: [] },
      timer: { intervalId: null, seconds: 0 },
      activeFilters: { examId: null, grade: null, types: [], status: { flagged: false, incorrect: false, unanswered: false } },
      buttonStates: {},
      cat2Containers: [],
      cat3Containers: [], // Added
      currentListIds: [],
      lastPageId: 'home-page',
      currentPageId: 'home-page'
    };

    document.addEventListener('DOMContentLoaded', async () => {
      const params = new URLSearchParams(window.location.search);
      if (params.has('userId')) quizState.userId = params.get('userId');
      setupUI(); initTheme(); await loadInitialData();
    });

    function setupUI() {
        const toggles = document.querySelectorAll('.nav-item');
        toggles.forEach(t => t.addEventListener('click', () => { toggles.forEach(x => x.classList.remove('active')); t.classList.add('active'); }));
        const statusContainer = document.getElementById('filter-status-buttons');
        if(statusContainer) {
            statusContainer.innerHTML = '';
            [{label: 'フラグ', value: 'flagged'}, {label: '不正解 (直近1問)', value: 'incorrect'}, {label: '未解答', value: 'unanswered'}].forEach(s => {
                const btn = createButtonElement(s.label, false); 
                btn.id = `btn-status-${s.value}`;
                btn.onclick = () => { const isActive = btn.getAttribute('aria-pressed') === 'true'; toggleStatusFilter(btn, s.value, !isActive); };
                statusContainer.appendChild(btn);
            });
        }
    }

    function initTheme() {
        const savedTheme = localStorage.getItem('theme');
        const isDark = savedTheme === 'dark' || (!savedTheme && window.matchMedia('(prefers-color-scheme: dark)').matches);
        if (isDark) document.documentElement.classList.add('dark');
        quizState.settings.darkMode = isDark;
        updateThemeToggleUI(isDark);
    }

    function toggleDarkMode() {
        const isDark = document.documentElement.classList.toggle('dark');
        localStorage.setItem('theme', isDark ? 'dark' : 'light');
        quizState.settings.darkMode = isDark;
        updateThemeToggleUI(isDark);
        saveSettings();
    }

    function updateThemeToggleUI(isDark) {
        const toggleBtn = document.getElementById('setting-darkmode-toggle');
        if (toggleBtn) toggleBtn.checked = isDark;
    }

    function updateFontSize(val) {
        const size = parseInt(val, 10);
        document.documentElement.style.setProperty('--app-font-size', `${size}px`);
        document.getElementById('font-size-value').textContent = `${size}px`;
        quizState.settings.fontSize = size;
    }

    
    function applySavedSettings() {
        const savedSize = quizState.settings.fontSize || 16;
        updateFontSize(savedSize);
        if(document.getElementById('setting-font-size-slider')) document.getElementById('setting-font-size-slider').value = savedSize;
        if(document.getElementById('setting-omakase-count')) document.getElementById('setting-omakase-count').value = quizState.settings.omakaseCount || 10;
        if(document.getElementById('setting-answer-mode')) document.getElementById('setting-answer-mode').value = quizState.settings.answerMode || 'instant';
        if(document.getElementById('setting-timer-toggle')) document.getElementById('setting-timer-toggle').checked = quizState.settings.showTimer !== false;
        if(document.getElementById('setting-darkmode-toggle')) document.getElementById('setting-darkmode-toggle').checked = quizState.settings.darkMode;

        
        if (quizState.settings.email) quizState.userId = quizState.settings.email;
        if(document.getElementById('setting-account-id')) document.getElementById('setting-account-id').textContent = quizState.userId;
    }

    // --- Master Data Helpers ---
    function getSortOrder(val, type, parentVal = null) {
        if (!quizState.masterData.sortMaster) return 9999;
        let item;
        if (parentVal) {
             item = quizState.masterData.sortMaster.find(row => 
                row.master_type === type && row.value === val && row.parent_value_1 === parentVal
            );
        }
        if (!item) {
            item = quizState.masterData.sortMaster.find(row => 
                row.master_type === type && row.value === val
            );
        }
        return item ? (parseInt(item.sort_order) || 9999) : 9999;
    }

    function formatLabel(val, type, parentVal = null) {
        if (!val) return '';
        if (type === 'exam_grade' || type === 'exam_type') return val;
        const order = getSortOrder(val, type, parentVal);
        return (order !== 9999) ? `${order}. ${val}` : val;
    }

    function sortByMaster(items, type, parentVal = null) {
        return items.sort((a, b) => {
            const oa = getSortOrder(a, type, parentVal);
            const ob = getSortOrder(b, type, parentVal);
            if (oa !== ob) return oa - ob;
            return String(a).localeCompare(String(b), 'ja');
        });
    }

    function createMultiSelectButtons(containerId, items, onChangeCallback, defaultLabel = "すべて") {
        const container = document.getElementById(containerId);
        if(!container) return;
        if (!quizState.buttonStates[containerId]) { quizState.buttonStates[containerId] = { values: ['all'], items: items, onChange: onChangeCallback }; } 
        else { quizState.buttonStates[containerId].items = items; quizState.buttonStates[containerId].values = ['all']; }
        renderButtons(containerId, defaultLabel);
    }

    function renderButtons(containerId, defaultLabel) {
        const container = document.getElementById(containerId);
        const state = quizState.buttonStates[containerId];
        if (!container || !state) return;
        const selectedValues = state.values;
        container.innerHTML = '';
        if (!state.items || state.items.length === 0) { container.innerHTML = '<span class="text-xs text-gray-400 py-2">選択可能な項目がありません</span>'; return; }
        const isAll = selectedValues.includes('all');
        const allBtn = createButtonElement(defaultLabel, isAll);
        allBtn.onclick = () => updateButtonSelection(containerId, 'all', defaultLabel);
        container.appendChild(allBtn);
        state.items.forEach(item => {
            const isSelected = selectedValues.includes(item.value);
            let type = getMasterTypeFromId(containerId);
            const parentContext = null; // Need context?
            const btn = createButtonElement(formatLabel(item.label, type), isSelected);
            btn.onclick = () => updateButtonSelection(containerId, item.value, defaultLabel);
            container.appendChild(btn);
        });
    }

    
    function getMasterTypeFromId(id) {
        if (id.includes('cat1')) return 'category_1';
        if (id.includes('cat2')) return 'category_2';
        if (id.includes('cat3')) return 'category_3';
        if (id.includes('type')) return 'exam_type';
        return null;
    }

    function createButtonElement(label, isActive) {
        const btn = document.createElement('button');
        btn.type = 'button';
        btn.className = `inline-flex items-center justify-center px-4 py-2 rounded-full text-xs font-bold border transition-all duration-200 cursor-pointer select-none min-h-[36px] shadow-sm touch-manipulation gap-1 ${isActive ? 'bg-teal-600 text-white border-teal-600 shadow-md ring-2 ring-teal-100 ring-offset-1 animate-pop dark:bg-teal-500 dark:border-teal-500 dark:ring-teal-900 dark:ring-offset-slate-900 opacity-100' : 'bg-white text-slate-500 border-slate-200 hover:bg-slate-50 hover:border-slate-300 dark:bg-slate-800 dark:text-slate-400 dark:border-slate-700 dark:hover:bg-slate-700 dark:hover:border-slate-600'}`;
        if (isActive) btn.innerHTML = `<svg class="w-3.5 h-3.5 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M5 13l4 4L19 7"></path></svg><span>${label}</span>`;
        else btn.textContent = label;
        btn.setAttribute('aria-pressed', isActive);
        return btn;
    }

    function updateButtonSelection(containerId, value, defaultLabel) {
        const state = quizState.buttonStates[containerId];
        if (!state) return;
        if (value === 'all') { state.values = ['all']; } 
        else {
            if (state.values.includes('all')) state.values = [];
            const idx = state.values.indexOf(value);
            if (idx > -1) state.values.splice(idx, 1); else state.values.push(value);
            if (state.values.length === 0) state.values = ['all'];
        }
        renderButtons(containerId, defaultLabel);
        if (state.onChange) state.onChange(state.values);
    }

    function getButtonSelectedValues(containerId) { return quizState.buttonStates[containerId] ? quizState.buttonStates[containerId].values : ['all']; }

    async function loadInitialData() {
      showLoading(true, 'データを読み込んでいます...');
      try {
        if (typeof SERVER_INITIAL_SETTINGS !== 'undefined' && SERVER_INITIAL_SETTINGS) { quizState.settings = { ...quizState.settings, ...SERVER_INITIAL_SETTINGS }; } 
        else { google.script.run.withSuccessHandler(s => { if(s) quizState.settings = { ...quizState.settings, ...s }; }).getUserSettings(quizState.userId); }

        google.script.run.withSuccessHandler(data => {
            if (data.error) { 
                showLoading(false); 
                alert("データの読み込みに失敗しました。\nエラー: " + (data.message || "不明なエラー") + "\n\nスプレッドシートのシート名を確認してください。");
                return; 
            }
            quizState.masterData = { ...quizState.masterData, ...data };
            if (!data.questions) quizState.masterData.questions = [];
            if (!data.questionsMeta) quizState.masterData.questionsMeta = [];
            if(data.questionsMeta) data.questionsMeta.forEach(q => { if (q.isFlagged) quizState.flags.add(String(q.id)); });

            
            // Home flag count removed

            
            try { 
                applySavedSettings(); 
                populateHomeFilters(); 
                populateSettingsResetOptions();
                checkResumeState(); 
                showPage(quizState.currentPageId || 'home-page');
            } catch (e) { console.error(e); }
            showLoading(false);
        }).withFailureHandler(e => { 
            showLoading(false); 
            alert("通信エラーが発生しました。\n再読み込みしてください。");
        }).getInitialData(quizState.userId);
      } catch (e) { showLoading(false); }
    }

    function checkResumeState() {
        const card = document.getElementById('resume-card-container');
        const data = quizState.settings.resumeData;
        if (data && data.questionId) {
            const q = quizState.masterData.questionsMeta.find(m => String(m.id) === String(data.questionId));
            if (q) {
                const timeStr = data.timestamp ? new Date(data.timestamp).toLocaleString('ja-JP', { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' }) : '';
                document.getElementById('resume-time-text').textContent = timeStr;
                const modeLabel = (data.mode === 'smart') ? 'スマート学習' : 'リスト学習';
                const progressText = (data.index !== undefined && data.total !== undefined) 
                    ? `${data.index + 1} / ${data.total} 問目` 
                    : `問${q.question_no}`;
                document.getElementById('resume-info-text').textContent = `${modeLabel} ${progressText} (${q.exam})`;
            }
            card.classList.remove('hidden');
        } else {
            card.classList.add('hidden');
        }
    }

    function resumeLearning() {
        const data = quizState.settings.resumeData;
        if (!data || !data.questionId) return;
        startQuizFromList(data.questionId);
    }

    
    function handleResumeDelete() {
        if(!confirm('中断した学習データを削除しますか？')) return;
        quizState.settings.resumeData = null;
        google.script.run.saveUserSettings(quizState.userId, JSON.stringify(quizState.settings));
        checkResumeState();
    }

    
    function updateHeaderContext() {
        const contextDiv = document.getElementById('header-context-info');
        const examSelect = document.getElementById('global-exam-select');
        const gradeSelect = document.getElementById('global-grade-select');
        let text = "すべてのデータ";
        if (examSelect.selectedIndex > 0 && gradeSelect.value) {
            const gradeLabel = formatLabel(gradeSelect.value, 'exam_grade');
            text = `${examSelect.options[examSelect.selectedIndex].text} ${gradeLabel}`;
            contextDiv.textContent = text; contextDiv.classList.remove('hidden');
        } else { contextDiv.classList.add('hidden'); }
    }

    function populateHomeFilters() {
        const examSelect = document.getElementById('global-exam-select');
        if(!examSelect) return;

        
        try {
            const exams = (quizState.masterData && quizState.masterData.exams) ? quizState.masterData.exams : [];

            
            if(exams.length === 0) {
                examSelect.innerHTML = '<option value="" disabled selected>データなし</option>';
                return;
            }

            const uniqueNames = new Set();
            exams.forEach(e => {
                 const name = e.exam_name || e.name || e.ExamName;
                 if(name) uniqueNames.add(name);
            });
            const sortedNames = Array.from(uniqueNames).sort();

            if (sortedNames.length === 0) {
                 examSelect.innerHTML = '<option value="" disabled selected>データなし (試験名不明)</option>';
                 return;
            }

            examSelect.innerHTML = '<option value="" disabled selected>選択してください</option>';
            sortedNames.forEach(name => { 
                const opt = document.createElement('option'); 
                opt.value = name; 
                opt.textContent = name; 
                examSelect.appendChild(opt); 
            });

            
            if (quizState.settings.lastFilter && quizState.settings.lastFilter.examName) {
                 const savedName = quizState.settings.lastFilter.examName;
                 if(Array.from(examSelect.options).some(o => o.value === savedName)) {
                      examSelect.value = savedName;
                      onExamSelectChange(quizState.settings.lastFilter.grade);
                 }
            }
        } catch (e) {
            console.error("Filter Populate Error:", e);
            examSelect.innerHTML = '<option value="" disabled selected>エラーが発生しました</option>';
        }
    }

    function populateSettingsResetOptions() {
        const select = document.getElementById('setting-reset-target');
        if (!select) return;
        select.innerHTML = '<option value="all">すべての学習履歴</option>';

        
        const exams = quizState.masterData.exams || [];
        exams.forEach(e => {
             const name = e.exam_name || e.name;
             const grade = e.exam_grade || e.grade;
             if(name && grade) {
                 const opt = document.createElement('option');
                 opt.value = `${name} ${grade}`;
                 opt.textContent = `${name} ${grade} のみ`;
                 select.appendChild(opt);
             }
        });
    }

    function handleResetHistory() {
        const target = document.getElementById('setting-reset-target').value;
        const msg = target === 'all' ? 'すべての学習履歴を削除しますか？' : `「${target}」に関する学習履歴を削除しますか？`;
        if (!confirm(msg + '\nこの操作は取り消せません。')) return;

        
        showLoading(true, '履歴を削除中...');
        google.script.run
            .withSuccessHandler(() => {
                showLoading(false);
                alert('履歴を削除しました。反映するには再読み込みしてください。');
                quizState.history = {}; 
                loadInitialData(); 
            })
            .withFailureHandler((e) => {
                showLoading(false);
                console.error(e);
                alert('削除に失敗しました');
            })
            .resetUserHistory(quizState.userId, target);
    }

    function onExamSelectChange(targetGrade = null) {
        const examName = document.getElementById('global-exam-select').value;
        const gradeSelect = document.getElementById('global-grade-select');

        
        const relevantExams = quizState.masterData.exams.filter(e => (e.exam_name || e.name) === examName);
        let uniqueGrades = [...new Set(relevantExams.map(e => e.exam_grade || e.grade))].filter(Boolean);
        uniqueGrades = sortByMaster(uniqueGrades, 'exam_grade');

        gradeSelect.innerHTML = '';
        uniqueGrades.forEach(g => { 
            const opt = document.createElement('option'); 
            opt.value = g; 
            opt.textContent = formatLabel(g, 'exam_grade'); 
            gradeSelect.appendChild(opt); 
        });

        
        if (targetGrade && uniqueGrades.includes(targetGrade)) {
            gradeSelect.value = targetGrade;
        } else if (uniqueGrades.length > 0) {
            gradeSelect.value = uniqueGrades[0];
        }
        updateGlobalFiltersState();
    }

    
    function updateGlobalFiltersState() {
        const examName = document.getElementById('global-exam-select').value;
        const grade = document.getElementById('global-grade-select').value;

        
        const targetExam = quizState.masterData.exams.find(e => (e.exam_name || e.name) === examName && (e.exam_grade || e.grade) === grade);
        const examId = targetExam ? String(targetExam.exam_id || targetExam.id) : null;

        quizState.activeFilters.examId = examId;
        quizState.activeFilters.grade = grade || null;

        
        if (examId && grade) {
            quizState.settings.lastFilter = { examName: examName, grade: grade };
            saveSettings();

        
            const relevantInstances = quizState.masterData.instances.filter(i => String(i.exam_id) === String(examId));
            let uniqueTypes = [...new Set(relevantInstances.map(i => i.exam_type))].filter(Boolean);
            uniqueTypes = sortByMaster(uniqueTypes, 'exam_type');

            
            const typeItems = uniqueTypes.map(t => ({ label: t, value: t }));
            createMultiSelectButtons('global-type-buttons', typeItems, (vals) => { 
                quizState.activeFilters.types = vals; 
                if(quizState.currentPageId === 'question-list-page') renderQuestionList();
                if(quizState.currentPageId === 'stats-page') loadStatsData();
            }, 'すべて');
        } else { quizState.activeFilters.types = []; }

        
        quizState.activeFilters.types = getButtonSelectedValues('global-type-buttons');
        updateHeaderContext();

        
        if(quizState.currentPageId === 'question-list-page') {
             populateListPageFilters();
             renderQuestionList();
        }
        if(quizState.currentPageId === 'stats-page') loadStatsData();
    }

    function getFilteredQuestionsBase(ignoreType = false) {
        const { examId, grade, types } = quizState.activeFilters;
        if (!examId) return []; 
        return quizState.masterData.questionsMeta.filter(q => {
            if (String(q.examId) !== String(examId)) return false;
            if (grade && q.grade !== grade) return false;
            if (!ignoreType && types && !types.includes('all')) { if (!types.includes(q.type)) return false; }
            return true;
        });
    }

    function populateListPageFilters() {
        const baseQuestions = getFilteredQuestionsBase(); 
        const { grade } = quizState.activeFilters;
        const uniqueEditions = [...new Set(baseQuestions.map(q => q.exam.replace(grade || '', '').trim()))].filter(Boolean).sort().reverse(); 
        const examItems = uniqueEditions.map(e => ({ label: e, value: e }));
        createMultiSelectButtons('filter-exam-buttons', examItems, renderQuestionList, "すべての回");

        
        let uniqueCat1 = [...new Set(baseQuestions.map(q => q.category))].filter(Boolean);
        uniqueCat1 = sortByMaster(uniqueCat1, 'category_1');
        const cat1Items = uniqueCat1.map(c => ({ label: formatLabel(c, 'category_1'), value: c }));
        createMultiSelectButtons('filter-cat1-buttons', cat1Items, (selectedCat1Vals) => { updateCat2Filter(selectedCat1Vals, baseQuestions); renderQuestionList(); }, "すべて");
        updateCat2Filter(['all'], baseQuestions);
    }

    
    function updateCat2Filter(selectedCat1Vals, baseQuestions) {
        const catContainer = document.getElementById('filter-cat2-grouped-area');
        catContainer.innerHTML = '';
        let targetQuestions = baseQuestions;
        if (selectedCat1Vals.length > 0 && !selectedCat1Vals.includes('all')) {
            targetQuestions = baseQuestions.filter(q => selectedCat1Vals.includes(q.category));
        }

        
        let uniqueCat1InTarget = [...new Set(targetQuestions.map(q => q.category))].filter(Boolean);
        uniqueCat1InTarget = sortByMaster(uniqueCat1InTarget, 'category_1');

        uniqueCat1InTarget.forEach((cat1, idx) => {
            const wrapper = document.createElement('div');
            const header = document.createElement('div');
            header.className = 'text-xs font-bold text-teal-700 dark:text-teal-400 mb-2 pl-1 border-l-4 border-teal-500 dark:border-teal-600 leading-none flex items-center h-4';
            header.textContent = formatLabel(cat1, 'category_1');
            wrapper.appendChild(header);
            const btnContainerId = `filter-cat2-group-${idx}`;
            const btnContainer = document.createElement('div');
            btnContainer.id = btnContainerId;
            btnContainer.className = 'flex flex-wrap gap-2 pl-2 mb-4';
            wrapper.appendChild(btnContainer);
            catContainer.appendChild(wrapper);

            
            const cat1Questions = baseQuestions.filter(q => q.category === cat1);
            let uniqueCat2 = [...new Set(cat1Questions.map(q => q.category2))].filter(Boolean);
            uniqueCat2 = sortByMaster(uniqueCat2, 'category_2', cat1);

            
            if(uniqueCat2.length === 0) {
                btnContainer.innerHTML = '<span class="text-xs text-gray-400">中分類なし</span>';
            } else {
                const cat2Items = uniqueCat2.map(c => ({ 
                    label: formatLabel(c, 'category_2', cat1), 
                    value: c 
                }));
                // Chain to Cat3 update
                createMultiSelectButtons(btnContainerId, cat2Items, () => {
                    updateCat3FilterWrapper(baseQuestions);
                    renderQuestionList();
                }, "すべて");

                
                if (!quizState.cat2Containers) quizState.cat2Containers = [];
                if (!quizState.cat2Containers.includes(btnContainerId)) quizState.cat2Containers.push(btnContainerId);
            }
        });

        
        if(uniqueCat1InTarget.length === 0) {
             catContainer.innerHTML = '<div class="text-xs text-gray-400 text-center py-2">該当する中分類はありません</div>';
        }

        
        updateCat3FilterWrapper(baseQuestions);
    }

    function updateCat3FilterWrapper(baseQuestions) {
        // Collect selected Cat2s
        let selectedCat2s = new Set();
        let isCat2All = true;
        if (quizState.cat2Containers) {
            quizState.cat2Containers.forEach(id => {
                const vals = getButtonSelectedValues(id);
                if (!vals.includes('all')) { isCat2All = false; vals.forEach(v => selectedCat2s.add(v)); }
            });
        }

        // Filter questions for Cat3 generation
        let targetQuestions = baseQuestions;
        // Cat1 filtering is already implicit in baseQuestions passed to Cat2, BUT we need to check Cat2 selection
        if (!isCat2All) {
            targetQuestions = baseQuestions.filter(q => q.category2 && selectedCat2s.has(q.category2));
        } else {
            // Even if "All" Cat2 is selected, we need to respect the available Cat2s (which are filtered by Cat1)
            // baseQuestions is already filtered by Cat1 selection in populateListPageFilters -> updateCat2Filter
        }

        const catContainer = document.getElementById('filter-cat3-grouped-area');
        catContainer.innerHTML = '';

        // Group by Cat2 to show Cat3s
        let uniqueCat2InTarget = [...new Set(targetQuestions.map(q => q.category2))].filter(Boolean);
        // Sort Cat2
        uniqueCat2InTarget.sort((a,b) => {
             // Need parent Cat1 for accurate sort? Assuming baseQuestions context is enough or global sort is OK
             // Better to sort by Order
             return getSortOrder(a, 'category_2') - getSortOrder(b, 'category_2'); 
        });

        uniqueCat2InTarget.forEach((cat2, idx) => {
            const wrapper = document.createElement('div');
            const header = document.createElement('div');
            header.className = 'text-xs font-bold text-teal-700 dark:text-teal-400 mb-2 pl-1 border-l-4 border-teal-500 dark:border-teal-600 leading-none flex items-center h-4';
            header.textContent = formatLabel(cat2, 'category_2');
            wrapper.appendChild(header);
            const btnContainerId = `filter-cat3-group-${idx}`;
            const btnContainer = document.createElement('div');
            btnContainer.id = btnContainerId;
            btnContainer.className = 'flex flex-wrap gap-2 pl-2 mb-4';
            wrapper.appendChild(btnContainer);
            catContainer.appendChild(wrapper);

            const cat2Questions = targetQuestions.filter(q => q.category2 === cat2);
            let uniqueCat3 = [...new Set(cat2Questions.map(q => q.category3))].filter(Boolean);
            uniqueCat3 = sortByMaster(uniqueCat3, 'category_3', cat2);

            if (uniqueCat3.length === 0) {
                 btnContainer.innerHTML = '<span class="text-xs text-gray-400">小分類なし</span>';
            } else {
                 const cat3Items = uniqueCat3.map(c => ({
                     label: formatLabel(c, 'category_3', cat2),
                     value: c
                 }));
                 createMultiSelectButtons(btnContainerId, cat3Items, renderQuestionList, "すべて");
                 if (!quizState.cat3Containers) quizState.cat3Containers = [];
                 if (!quizState.cat3Containers.includes(btnContainerId)) quizState.cat3Containers.push(btnContainerId);
            }
        });

        if (uniqueCat2InTarget.length === 0) {
             catContainer.innerHTML = '<div class="text-xs text-gray-400 text-center py-2">該当する小分類はありません</div>';
        }
    }

    function toggleFilterMode() {
        const mode = document.querySelector('input[name="list-filter-mode"]:checked').value;
        const examArea = document.getElementById('filter-exam-area');
        const catArea = document.getElementById('filter-category-area');
        if (mode === 'exam') { examArea.classList.remove('hidden'); catArea.classList.add('hidden'); } 
        else { examArea.classList.add('hidden'); catArea.classList.remove('hidden'); }
        renderQuestionList();
    }
    window.toggleFilterMode = toggleFilterMode;

    function toggleStatusFilter(btn, type, isActive) {
        const newBtn = createButtonElement(btn.textContent, isActive);
        newBtn.id = btn.id; newBtn.onclick = () => toggleStatusFilter(newBtn, type, !isActive);
        btn.parentNode.replaceChild(newBtn, btn);
        if (type === 'flagged') quizState.activeFilters.status.flagged = isActive;
        if (type === 'incorrect') quizState.activeFilters.status.incorrect = isActive;
        if (type === 'unanswered') quizState.activeFilters.status.unanswered = isActive;
        renderQuestionList();
    }

    function renderQuestionList() {
        const container = document.getElementById('question-list-container');
        const keyword = document.getElementById('filter-keyword').value.toLowerCase();
        const sortMode = document.getElementById('list-sort-select').value;
        const mode = document.querySelector('input[name="list-filter-mode"]:checked').value;
        const selectedExams = getButtonSelectedValues('filter-exam-buttons');

        
        // Cat1
        const selectedCat1 = getButtonSelectedValues('filter-cat1-buttons');

        
        // Cat2
        let selectedCat2s = new Set(); let isCat2All = true;
        if (quizState.cat2Containers) {
            quizState.cat2Containers.forEach(id => {
                const vals = getButtonSelectedValues(id);
                if (!vals.includes('all')) { isCat2All = false; vals.forEach(v => selectedCat2s.add(v)); }
            });
        }

        // Cat3
        let selectedCat3s = new Set(); let isCat3All = true;
        if (quizState.cat3Containers) {
            quizState.cat3Containers.forEach(id => {
                const vals = getButtonSelectedValues(id);
                if (!vals.includes('all')) { isCat3All = false; vals.forEach(v => selectedCat3s.add(v)); }
            });
        }

        const { flagged, incorrect, unanswered } = quizState.activeFilters.status;
        let listData = getFilteredQuestionsBase();

        
        quizState.currentListIds = [];
        container.innerHTML = '';
        if (listData.length === 0) { container.innerHTML = '<div class="text-center py-10 text-sub">データがありません<br><span class="text-xs text-gray-400">学習対象を選択してください</span></div>'; document.getElementById('list-count').textContent = "0"; return; }

        listData = listData.filter(q => {
            if (keyword) {
                const matchText = (q.text || "").toLowerCase().includes(keyword);
                const matchCat = (q.category||"").toLowerCase().includes(keyword) || (q.category2||"").toLowerCase().includes(keyword) || (q.category3||"").toLowerCase().includes(keyword);
                if (!matchText && !matchCat) return false;
            }
            if (mode === 'exam') {
                const edition = q.exam.replace(quizState.activeFilters.grade || '', '').trim();
                if (!selectedExams.includes('all') && !selectedExams.includes(edition)) return false;
            } else {
                if (!selectedCat1.includes('all') && !selectedCat1.includes(q.category)) return false;
                if (!isCat2All && (!q.category2 || !selectedCat2s.has(q.category2))) return false;
                if (!isCat3All && (!q.category3 || !selectedCat3s.has(q.category3))) return false;
            }
            if (flagged || incorrect || unanswered) {
                let match = false;
                if (flagged && quizState.flags.has(String(q.id))) match = true;
                if (incorrect && q.isCorrect === false) match = true;
                if (unanswered && q.isCorrect === null) match = true; // null means no history
                if (!match) return false;
            }
            return true;
        });

        if (sortMode === 'accuracy_asc') listData.sort((a, b) => getAccuracyRate(a.history) - getAccuracyRate(b.history));
        else if (sortMode === 'accuracy_desc') listData.sort((a, b) => getAccuracyRate(b.history) - getAccuracyRate(a.history));
        else if (sortMode === 'newest') listData.sort((a, b) => b.exam.localeCompare(a.exam));
        else {
            // Default: Sort by Category Master Order
            listData.sort((a, b) => {
                const cat1A = getSortOrder(a.category, 'category_1');
                const cat1B = getSortOrder(b.category, 'category_1');
                if (cat1A !== cat1B) return cat1A - cat1B;
                const cat2A = getSortOrder(a.category2, 'category_2', a.category);
                const cat2B = getSortOrder(b.category2, 'category_2', b.category);
                if (cat2A !== cat2B) return cat2A - cat2B;
                const cat3A = getSortOrder(a.category3, 'category_3', a.category2);
                const cat3B = getSortOrder(b.category3, 'category_3', b.category2);
                if (cat3A !== cat3B) return cat3A - cat3B;
                return (a.question_no || 0) - (b.question_no || 0);
            });
        }

        
        // Update current list IDs for batch start (limit 100)
        quizState.currentListIds = listData.slice(0, 100).map(q => q.id);

        let count = 0;
        const fragment = document.createDocumentFragment();
        listData.forEach(q => {
            count++; if (count > 100) return;
            const div = document.createElement('div');
            div.className = 'bg-white dark:bg-slate-800 p-4 rounded-lg border border-gray-200 dark:border-gray-700 shadow-sm flex flex-col gap-2 hover:bg-gray-50 dark:hover:bg-slate-700 cursor-pointer transition-colors';
            div.onclick = () => startQuizFromList(q.id);
            let historyDots = '';
            if(q.history && q.history.length > 0) {
                const dots = q.history.slice(-5).map(r => `<span class="w-2 h-2 rounded-full ${r ? 'bg-teal-500' : 'bg-red-500'}"></span>`).join('');
                historyDots = `<div class="flex gap-0.5 ml-auto">${dots}</div>`;
            }
            div.innerHTML = `                <div class="flex justify-between items-start">
                     <div class="flex flex-wrap gap-1.5 items-center">
                        <span class="text-[10px] font-bold px-1.5 py-0.5 bg-gray-100 dark:bg-slate-700 text-gray-600 dark:text-gray-300 rounded border border-gray-200 dark:border-gray-600">${q.exam.replace(quizState.activeFilters.grade||'', '').trim()}</span>
                        <span class="text-[10px] font-bold px-1.5 py-0.5 bg-gray-100 dark:bg-slate-700 text-gray-600 dark:text-gray-300 rounded border border-gray-200 dark:border-gray-600">${formatLabel(q.type||'-', 'exam_type')}</span>
                        <span class="text-[10px] font-bold px-1.5 py-0.5 bg-indigo-50 dark:bg-indigo-900/30 text-indigo-600 dark:text-indigo-300 rounded border border-indigo-100 dark:border-indigo-800">大問${q.scenario_no||'-'}</span>
                        <span class="text-[10px] font-bold px-1.5 py-0.5 bg-teal-50 dark:bg-teal-900/30 text-teal-600 dark:text-teal-300 rounded border border-teal-100 dark:border-teal-800">問${q.question_no||'-'}</span>
                        ${quizState.flags.has(String(q.id)) ? '<svg class="w-3.5 h-3.5 text-amber-400 fill-current flex-shrink-0" viewBox="0 0 24 24"><path d="M5 3v18l7-5 7 5V3z"></path></svg>' : ''}
                     </div>
                     ${historyDots}
                </div>
                <div class="flex flex-wrap gap-1 text-[10px] text-slate-500 dark:text-slate-400 mt-1">
                    <span class="font-bold text-slate-600 dark:text-slate-300">${formatLabel(q.category, 'category_1')}</span>
                    ${q.category2 ?`<span class="text-gray-300">/</span> <span>${formatLabel(q.category2, 'category_2', q.category)}</span>` : ''}
                    ${q.category3 ? `<span class="text-gray-300">/</span> <span>${formatLabel(q.category3, 'category_3', q.category2)}</span>` : ''}
                </div>`;
            fragment.appendChild(div);
        });
        container.appendChild(fragment);
        document.getElementById('list-count').textContent = listData.length > 100 ? `${count}+` : count;
        if (count === 0) container.innerHTML = '<div class="text-center py-10 text-sub">条件に一致する問題が見つかりません</div>';
    }

    
    function getAccuracyRate(history) { if (!history || history.length === 0) return -1; return history.filter(h => h).length / history.length; }

    
    function startListQuiz() {
        if (quizState.currentListIds.length === 0) { alert('出題対象となる問題がありません'); return; }
        if (!confirm(`表示中の問題（最大${quizState.currentListIds.length}件）で出題を開始しますか？`)) return;
        showLoading(true);
        google.script.run.withSuccessHandler(q => {
            showLoading(false);
            initQuizSession(q, 'list');
        }).getQuestionsByIds(quizState.userId, quizState.currentListIds);
    }

    function startSmartQuiz() { 
        showLoading(true); 
        google.script.run.withSuccessHandler(q => { 
            showLoading(false); 
            initQuizSession(q, 'smart'); 
        }).getSmartQuestions(quizState.userId, quizState.settings.omakaseCount || 10, quizState.activeFilters); 
    }

    
    function startFlaggedQuiz() {
        if (quizState.flags.size === 0) { alert('フラグ付きの問題がありません'); return; }
        if (!confirm(`フラグ付きの問題（全${quizState.flags.size}問）を出題しますか？\n（現在の学習対象設定: ${quizState.activeFilters.examId ? "適用中" : "なし"}）`)) return;
        showLoading(true);
        google.script.run.withSuccessHandler(q => {
            showLoading(false);
            if(q.length === 0) { alert("選択された学習対象（試験名・級）に合致するフラグ付き問題がありません。"); return; }
            initQuizSession(q, 'list');
        }).getFlaggedQuestions(quizState.userId, 20, quizState.activeFilters);
    }

    
    // 修正: backendのgetQuestionDetailを呼び出すように変更
    function startQuizFromList(id) { 
        showLoading(true); 
        google.script.run.withSuccessHandler(q => { 
            showLoading(false); 
            if(!q || q.length === 0) { alert('問題データを取得できませんでした'); return; }
            initQuizSession(q, 'list'); 
        }).getQuestionDetail(quizState.userId, id); 
    }

    
    function showPage(pageId) {
        if (quizState.currentPageId && pageId !== 'settings-page' && quizState.currentPageId !== 'settings-page') quizState.lastPageId = quizState.currentPageId;
        quizState.currentPageId = pageId;
        document.querySelectorAll('.page-section').forEach(el => el.classList.add('hidden'));
        document.getElementById(pageId).classList.remove('hidden');
        window.scrollTo(0, 0);

        
        // Show/Hide Global Filter
        const globalFilter = document.getElementById('global-filter-section');
        if (pageId === 'quiz-page' || pageId === 'result-page') {
             globalFilter.classList.add('hidden');
        } else {
             globalFilter.classList.remove('hidden');
        }

        
        document.querySelectorAll('.nav-item').forEach(n => n.classList.remove('active'));
        if(pageId === 'home-page') document.getElementById('nav-home').classList.add('active');
        if(pageId === 'question-list-page') document.getElementById('nav-list').classList.add('active');
        if(pageId === 'stats-page') document.getElementById('nav-stats').classList.add('active');

        
        if (pageId === 'quiz-page') document.querySelector('#global-nav').classList.add('hidden'); else document.querySelector('#global-nav').classList.remove('hidden');

        
        if (pageId === 'question-list-page') {
            setTimeout(() => { populateListPageFilters(); renderQuestionList(); }, 50);
        }
        if (pageId === 'stats-page') {
            loadStatsData();
        }
    }

    
    function toggleSettingsModal() {
        const modal = document.getElementById('settings-modal');
        if (modal.classList.contains('hidden')) {
            modal.classList.remove('hidden');
        } else {
            modal.classList.add('hidden');
        }
    }
    // Backward compat
    function toggleSettingsPage() { toggleSettingsModal(); }

    function showLoading(show, msg) { document.getElementById('loading-overlay').classList.toggle('hidden', !show); if(msg) document.getElementById('loading-message').textContent = msg; }
    function saveSettings() { 
        quizState.settings.omakaseCount = document.getElementById('setting-omakase-count').value;
        quizState.settings.answerMode = document.getElementById('setting-answer-mode').value;
        quizState.settings.showTimer = document.getElementById('setting-timer-toggle').checked;
        google.script.run.saveUserSettings(quizState.userId, JSON.stringify(quizState.settings)); 
    }

    
    function initQuizSession(q, mode = 'list') { 
        if(!q || q.length===0) { alert('問題データがありません'); return; } 
        q.forEach(quest => {
            if(!quest.exam_edition || !quest.exam_grade) {
                const meta = quizState.masterData.questionsMeta.find(m => String(m.id) === String(quest.id));
                if(meta) {
                    quest.exam_edition = meta.exam; 
                    quest.exam_type = meta.type;
                    quest.exam_grade = meta.grade;
                    if(!quest.category) quest.category = meta.category;
                    if(!quest.category2) quest.category2 = meta.category2;
                    if(!quest.category3) quest.category3 = meta.category3;
                }
            }
        });
        quizState.currentSet = q; 
        quizState.currentIndex = 0; 
        quizState.sessionResults = []; 
        quizState.currentMode = mode; 
        showPage('quiz-page'); 
        renderQuestion(q[0]); 
    }

    
    function startTimer() {
        stopTimer(); quizState.timer.seconds = 0; updateTimerDisplay();
        const display = document.getElementById('timer-display');
        if (!quizState.settings.showTimer) { display.classList.add('hidden'); return; }
        display.classList.remove('hidden');
        quizState.timer.intervalId = setInterval(() => { quizState.timer.seconds++; updateTimerDisplay(); }, 1000);
    }
    function stopTimer() { if (quizState.timer.intervalId) { clearInterval(quizState.timer.intervalId); quizState.timer.intervalId = null; } }
    function updateTimerDisplay() { const sec = quizState.timer.seconds; const m = Math.floor(sec / 60).toString().padStart(2, '0'); const s = (sec % 60).toString().padStart(2, '0'); document.getElementById('timer-display').textContent = `${m}:${s}`; }

    function \_normalizeAnswer(val) {
        if (!val) return "";
        let s = String(val);
        s = s.replace(/[Ａ-Ｚａ-ｚ０-９]/g, function(s) {
            return String.fromCharCode(s.charCodeAt(0) - 0xFEE0);
        });
        s = s.replace(/\s+/g, "");
        return s.toLowerCase();
    }

    function renderQuestion(q) {
        startTimer();
        document.getElementById('quiz-info-edition').textContent = q.exam_edition ? q.exam_edition.replace(quizState.activeFilters.grade||'', '').trim() : '';
        document.getElementById('quiz-info-type').textContent = formatLabel(q.exam_type||'', 'exam_type');
        document.getElementById('quiz-info-s-no').textContent = q.scenario_no ? `大問 ${q.scenario_no}` : '-';
        document.getElementById('quiz-info-q-no').textContent = q.question_no ? `問 ${q.question_no}` : '-';
        document.getElementById('quiz-info-cat1').textContent = formatLabel(q.category||'', 'category_1');
        document.getElementById('quiz-info-cat2').textContent = formatLabel(q.category2||'', 'category_2', q.category);
        document.getElementById('quiz-info-cat3').textContent = formatLabel(q.category3||'', 'category_3', q.category2);
        document.getElementById('quiz-question-text').textContent = q.text || "Error";

        const wrapper = document.getElementById('quiz-scenario-wrapper');
        const mobileWrapper = document.getElementById('quiz-scenario-accordion-wrapper');
        if (q.scenario) {
            const text = typeof q.scenario === 'object' ? q.scenario.text : q.scenario;
            const no = typeof q.scenario === 'object' ? q.scenario.no : (q.scenario_no || '');
            document.getElementById('quiz-scenario-text-desktop').textContent = text;
            document.getElementById('quiz-scenario-text-mobile').textContent = text;
            const noDesk = document.getElementById('quiz-scenario-no-desktop'); const noMob = document.getElementById('quiz-scenario-no-mobile');
            if (no) { noDesk.textContent = `大問 ${no}`; noDesk.classList.remove('hidden'); noMob.textContent = `大問 ${no}`; noMob.classList.remove('hidden'); } else { noDesk.classList.add('hidden'); noMob.classList.add('hidden'); }
            wrapper.classList.remove('hidden'); mobileWrapper.classList.remove('hidden');
        } else { wrapper.classList.add('hidden'); mobileWrapper.classList.add('hidden'); }

        const meta = quizState.masterData.questionsMeta ? quizState.masterData.questionsMeta.find(m => String(m.id) === String(q.id)) : null;
        const history = meta ? (meta.history || []) : [];
        const dotsContainer = document.getElementById('quiz-history-dots'); dotsContainer.innerHTML = '';
        if (history.length > 0) { history.slice(-5).forEach(isCorrect => { const dot = document.createElement('div'); dot.className = `w-2 h-2 rounded-full ${isCorrect ? 'bg-teal-500' : 'bg-red-500'}`; dotsContainer.appendChild(dot); }); }

        const choicesContainer = document.getElementById('quiz-choices-container'); choicesContainer.innerHTML = '';
        if (q.answer_type === 'TEXT' || (!q.choices || q.choices.length === 0)) {
            const inputWrapper = document.createElement('div'); inputWrapper.className = 'flex flex-col gap-4 mt-4';
            const input = document.createElement('textarea'); input.id = 'quiz-text-answer'; input.className = 'w-full p-4 rounded-xl border border-gray-300 dark:border-gray-600 bg-white dark:bg-slate-800 focus:ring-2 focus:ring-teal-500 outline-none transition-shadow text-base'; input.placeholder = 'ここに解答を入力してください...'; input.rows = 3;
            const submitBtn = document.createElement('button'); submitBtn.className = 'w-full py-4 rounded-xl bg-teal-600 text-white font-bold shadow-md hover:bg-teal-700 transition-colors flex items-center justify-center gap-2'; submitBtn.innerHTML = '解答する'; submitBtn.onclick = () => handleTextAnswer();
            inputWrapper.appendChild(input); inputWrapper.appendChild(submitBtn); choicesContainer.appendChild(inputWrapper);
        } else {
            q.choices.forEach((c, i) => {
                const btnWrapper = document.createElement('div'); btnWrapper.className = 'flex gap-2 w-full';
                const btn = document.createElement('button'); btn.className = 'flex-1 p-4 border border-gray-200 dark:border-gray-700 rounded-xl text-left bg-white dark:bg-slate-800 hover:bg-teal-50 dark:hover:bg-slate-700 transition-colors font-medium text-sm shadow-sm active:scale-[0.99] flex items-start group'; btn.onclick = () => handleAnswer(i); btn.id = `choice-btn-${i}`;
                btn.innerHTML = `<span class="font-bold mr-2 text-teal-600 dark:text-teal-400 mt-0.5">${i+1}.</span> <span class="group-hover:text-teal-900 dark:group-hover:text-white transition-colors">${c}</span>`;
                btnWrapper.appendChild(btn);
                if (quizState.settings.answerMode === 'elimination') {
                    const delBtn = document.createElement('button'); delBtn.className = 'w-12 flex items-center justify-center rounded-xl border border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-slate-800 text-gray-400 hover:text-red-500 hover:bg-red-50 dark:hover:bg-red-900/30 transition-colors'; delBtn.innerHTML = '<svg class="w-5 h-5 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path></svg>'; delBtn.onclick = () => toggleElimination(i); btnWrapper.appendChild(delBtn);
                }
                choicesContainer.appendChild(btnWrapper);
            });
        }
        document.getElementById('quiz-explanation-container').classList.add('hidden');
        renderFooterActions(false);
    }

    function toggleElimination(idx) { const btn = document.getElementById(`choice-btn-${idx}`); if(btn) btn.classList.toggle('choice-eliminated'); }

    function handleTextAnswer() {
        const input = document.getElementById('quiz-text-answer'); if(!input) return;
        const val = input.value.trim();
        if(!val) { input.classList.add('ring-2', 'ring-red-500'); setTimeout(() => input.classList.remove('ring-2', 'ring-red-500'), 500); return; }
        handleAnswer(val, true);
    }

    function handleAnswer(answerVal, isText = false) {
        stopTimer();
        const q = quizState.currentSet[quizState.currentIndex];
        let isCorrect = false;

        
        if (isText) { 
            const cleanAns = \_normalizeAnswer(answerVal);
            const cleanCorrect = \_normalizeAnswer(q.correct);
            isCorrect = (cleanAns === cleanCorrect); 
        } 
        else { isCorrect = (answerVal === q.correct); }

        
        quizState.sessionResults.push({ isCorrect: isCorrect, text: q.text, question: q });
        const saveVal = isText ? answerVal : answerVal; 
        google.script.run.saveHistory(quizState.userId, q.question_id, saveVal, isCorrect);

        
        document.getElementById('quiz-explanation-container').classList.remove('hidden');
        const display = document.getElementById('quiz-correct-answer-display');
        if (isText) { const input = document.getElementById('quiz-text-answer'); if(input) input.disabled = true; }

        
        const correctChoice = isText ? q.correct : (q.choices ? `${q.correct+1}. ${q.choices[q.correct]}` : q.correct);
        const userChoice = isText ? answerVal : (q.choices ? `${answerVal+1}. ${q.choices[answerVal]}` : answerVal);

        if(isCorrect) { 
            display.textContent = `正解！ (正解: ${correctChoice})`; 
            display.className = 'mb-3 p-3 rounded text-sm font-bold text-center bg-teal-100 text-teal-800 dark:bg-teal-900 dark:text-teal-200'; 
        } else { 
            display.innerHTML = `<div>不正解...</div><div class="mt-1 text-xs opacity-90">あなたの回答: ${userChoice}</div><div class="mt-1 text-base">正解: ${correctChoice}</div>`; 
            display.className = 'mb-3 p-3 rounded text-sm font-bold text-center bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200'; 
        }
        document.getElementById('quiz-explanation-text').innerHTML = q.explanation || "解説がありません。";
        renderFooterActions(true);
    }

    function handleBookmarkClick() {
        const q = quizState.currentSet[quizState.currentIndex]; const id = String(q.id || q.question_id); const isActive = quizState.flags.has(id);
        if (isActive) quizState.flags.delete(id); else quizState.flags.add(id);
        google.script.run.toggleReviewFlag(quizState.userId, id);
        renderFooterActions(document.getElementById('quiz-explanation-container').classList.contains('hidden') === false);
    }

    function handleReportClick() {
        const q = quizState.currentSet[quizState.currentIndex];
        const comment = prompt("問題の不備について報告します。\n内容を入力してください:", "誤字・脱字、正解の間違いなど");
        if(comment) {
            google.script.run.reportQuestionIssue(quizState.userId, q.id || q.question_id, "issue", comment);
            alert("報告を送信しました。ありがとうございます。");
        }
    }

    function renderFooterActions(isAnswered) {
        const footer = document.getElementById('quiz-footer-actions'); footer.innerHTML = '';
        const canGoBack = quizState.currentIndex > 0;
        const q = quizState.currentSet[quizState.currentIndex];
        const isFlagged = quizState.flags.has(String(q.id || q.question_id));
        const flagBtn = `<button onclick="handleBookmarkClick()" class="w-12 h-12 rounded-lg flex items-center justify-center transition-colors ${isFlagged ? 'text-amber-400 bg-amber-50 dark:bg-amber-900/20' : 'text-gray-400 hover:bg-gray-100 dark:hover:bg-slate-800'}"><svg class="w-6 h-6 ${isFlagged ? 'fill-current' : 'fill-none'} stroke-current flex-shrink-0" viewBox="0 0 24 24" stroke-width="2"><path d="M5 3v18l7-5 7 5V3z"></path></svg></button>`;
        // 追加: 不備報告ボタン
        const reportBtn = `<button onclick="handleReportClick()" class="w-8 h-8 rounded-full flex items-center justify-center text-gray-300 hover:text-red-500 hover:bg-red-50 dark:hover:bg-red-900/30 transition-colors ml-1" title="問題の不備を報告"><svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"></path></svg></button>`;

        
        if (!isAnswered) {
            footer.innerHTML = `${flagBtn}${reportBtn}<button onclick="handleSuspend()" class="px-3 py-3 rounded-lg bg-gray-100 dark:bg-slate-800 text-gray-600 dark:text-gray-300 font-bold text-xs hover:bg-gray-200 dark:hover:bg-slate-700 transition-colors flex-shrink-0 ml-auto">中断</button><button onclick="quizState.prevQuestionPre()" class="flex-1 py-3 rounded-lg border border-gray-200 dark:border-gray-700 text-gray-500 font-bold text-sm hover:bg-gray-50 dark:hover:bg-slate-800 transition-colors disabled:opacity-50" ${!canGoBack ? 'disabled' : ''}>戻る</button><button onclick="quizState.skipQuestion()" class="flex-[1.5] py-3 rounded-lg bg-gray-100 dark:bg-slate-800 text-gray-600 dark:text-gray-300 font-bold text-sm hover:bg-gray-200 dark:hover:bg-slate-700 transition-colors">進む</button>`;
        } else {
            footer.innerHTML = `<button onclick="handleSuspend()" class="hidden sm:block px-3 py-3 rounded-lg bg-gray-100 dark:bg-slate-800 text-gray-600 dark:text-gray-300 font-bold text-xs hover:bg-gray-200 dark:hover:bg-slate-700 transition-colors flex-shrink-0">中断</button>${flagBtn}${reportBtn}<button onclick="quizState.prevQuestionPre()" class="px-4 py-3 rounded-lg border border-gray-200 dark:border-gray-700 text-gray-500 font-bold text-sm hover:bg-gray-50 dark:hover:bg-slate-800 transition-colors disabled:opacity-50 ml-auto" ${!canGoBack ? 'disabled' : ''}>戻る</button><button onclick="handleRetry()" class="flex-1 py-3 rounded-lg bg-amber-100 dark:bg-amber-900/30 text-amber-700 dark:text-amber-400 font-bold text-sm hover:bg-amber-200 dark:hover:bg-amber-900/50 transition-colors">もう一度</button><button onclick="quizState.nextQuestion()" class="flex-[1.5] py-3 rounded-lg bg-teal-600 text-white font-bold text-sm shadow-md hover:bg-teal-700 transition-colors flex items-center justify-center gap-2">次へ<svg class="w-4 h-4 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"></path></svg></button>`;
        }
    }

    quizState.prevQuestionPre = function() { if (quizState.currentIndex > 0) { quizState.currentIndex--; renderQuestion(quizState.currentSet[quizState.currentIndex]); } }
    quizState.skipQuestion = function() { quizState.nextQuestion(); }
    function handleRetry() { renderQuestion(quizState.currentSet[quizState.currentIndex]); }
    function handleSuspend() { 
        if (!confirm('学習を中断してホームに戻りますか？\n（次回「学習を再開する」から続きを行えます）')) return; 
        const q = quizState.currentSet[quizState.currentIndex]; 
        quizState.settings.resumeData = { 
            questionId: q.id || q.question_id, 
            timestamp: new Date().getTime(),
            mode: quizState.currentMode || 'list', 
            index: quizState.currentIndex,          
            total: quizState.currentSet.length
        }; 
        google.script.run.saveUserSettings(quizState.userId, JSON.stringify(quizState.settings)); 
        showPage('home-page'); 
        checkResumeState(); 
    }

    quizState.nextQuestion = function() {
        stopTimer();
        if(quizState.currentIndex < quizState.currentSet.length-1) { quizState.currentIndex++; renderQuestion(quizState.currentSet[quizState.currentIndex]); } 
        else {
            showPage('result-page');
            const correct = quizState.sessionResults.filter(r=>r.isCorrect).length;
            const score = quizState.sessionResults.length > 0 ? Math.round(correct/quizState.sessionResults.length\*100) : 0;
            document.getElementById('result-score-text').textContent = score + "%";
            document.getElementById('result-list-container').innerHTML = quizState.sessionResults.map((r,i) => {
                const q = r.question || {}; 
                const statusIcon = r.isCorrect ? `<svg class="w-5 h-5 text-green-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M5 13l4 4L19 7"></path></svg>` : `<svg class="w-5 h-5 text-red-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M6 18L18 6M6 6l12 12"></path></svg>`;
                return `<div class="bg-white dark:bg-slate-800 p-4 rounded-lg border border-gray-200 dark:border-gray-700 shadow-sm flex flex-col gap-2"><div class="flex justify-between items-start"><div class="flex items-center gap-3">${statusIcon}<div class="flex flex-wrap gap-1.5 items-center"><span class="text-[10px] font-bold px-1.5 py-0.5 bg-gray-100 dark:bg-slate-700 text-gray-600 dark:text-gray-300 rounded border border-gray-200 dark:border-gray-600">${q.exam_edition ? q.exam_edition.replace(quizState.activeFilters.grade||'', '').trim() : ''}</span><span class="text-[10px] font-bold px-1.5 py-0.5 bg-indigo-50 dark:bg-indigo-900/30 text-indigo-600 dark:text-indigo-300 rounded border border-indigo-100 dark:border-indigo-800">大問${q.scenario_no||'-'}</span><span class="text-[10px] font-bold px-1.5 py-0.5 bg-teal-50 dark:bg-teal-900/30 text-teal-600 dark:text-teal-300 rounded border border-teal-100 dark:border-teal-800">問${q.question_no||'-'}</span></div></div></div><div class="flex flex-wrap gap-1 text-[10px] text-slate-500 dark:text-slate-400 mt-1 pl-8"><span class="font-bold text-slate-600 dark:text-slate-300">${formatLabel(q.category||'', 'category_1')}</span>${q.category2 ? `<span class="text-gray-300">/</span> <span>${formatLabel(q.category2, 'category_2')}</span>` : ''}</div></div>`;
            }).join('');
            if(quizState.settings.resumeData) { quizState.settings.resumeData = null; google.script.run.saveUserSettings(quizState.userId, JSON.stringify(quizState.settings)); checkResumeState(); }
        }
    }

    
    function retryMistakes() {  }
    function toggleScenario() { document.getElementById('quiz-scenario-content').classList.toggle('open'); }

    
    function loadStatsData() { 
        showLoading(true);
        const examName = document.getElementById('global-exam-select').value;
        const grade = document.getElementById('global-grade-select').value;
        const filters = { examName: examName, grade: grade || null };

        
        google.script.run.withSuccessHandler(d => {
            showLoading(false);
            if(d) {
                document.getElementById('stats-total-time').innerHTML = `${d.totalTime || 0}<span class="text-xs text-gray-500 ml-1">分</span>`;
                document.getElementById('stats-total-count').innerHTML = `${d.totalCount || 0}<span class="text-xs text-gray-500 ml-1">/</span><span class="text-[10px] text-gray-400 ml-1">${d.totalQuestions || 0}</span>`;
                document.getElementById('stats-accuracy').innerHTML = `${d.accuracy || 0}<span class="text-xs text-gray-500 ml-1">%</span>`;
                document.getElementById('stats-total-days').innerHTML = `${d.learningDays || 0}<span class="text-xs text-gray-500 ml-1">日</span>`;
                document.getElementById('stats-prediction').innerHTML = `${d.predictionDays || '--'}<span class="text-xs text-gray-500 ml-1">日</span>`;

                
                if (d.breakdown) {
                    const total = d.breakdown.correct + d.breakdown.incorrect + d.breakdown.unanswered;
                    const cp = total > 0 ? (d.breakdown.correct / total) _ 100 : 0; const ip = total > 0 ? (d.breakdown.incorrect / total) _ 100 : 0;
                    document.getElementById('bar-correct').style.width = `${cp}%`; document.getElementById('bar-incorrect').style.width = `${ip}%`;
                    document.getElementById('val-correct').textContent = d.breakdown.correct; document.getElementById('val-incorrect').textContent = d.breakdown.incorrect; document.getElementById('val-unanswered').textContent = d.breakdown.unanswered;
                }
                renderActivityCalendar(d.weeklyActivity || []); 

                
                const renderStackedList = (list, containerId, type) => {
                    const container = document.getElementById(containerId); if(!container) return;
                    list.sort((a, b) => getSortOrder(a.name, type) - getSortOrder(b.name, type));

                    
                    container.innerHTML = list.map(item => {
                        const total = item.total || 1; const cp = Math.round((item.correct / total) _ 100); const ip = Math.round((item.incorrect / total) _ 100);
                        return `<div class="space-y-1"><div class="flex justify-between text-xs text-slate-600 dark:text-slate-300"><span class="font-bold truncate w-2/3">${formatLabel(item.name, type)}</span><span>${item.rate}%</span></div><div class="h-2.5 w-full bg-gray-100 dark:bg-slate-700 rounded-full overflow-hidden flex"><div class="h-full bg-teal-500" style="width: ${cp}%"></div><div class="h-full bg-red-500" style="width: ${ip}%"></div></div><div class="text-[10px] text-right text-gray-400">正解:${item.correct} / 不正解:${item.incorrect} / 未:${item.unanswered}</div></div>`;
                    }).join('');
                };

                renderStackedList(d.typeList || [], 'stats-type-list', 'exam_type');
                renderStackedList(d.categoryList || [], 'stats-cat1-list', 'category_1');

                
                const cat2Container = document.getElementById('stats-cat2-list');
                if (cat2Container && d.category2List) {
                    cat2Container.innerHTML = '';
                    const grouped = {};
                    d.category2List.forEach(item => {
                        const p = item.parent || '未分類';
                        if (!grouped[p]) grouped[p] = [];
                        grouped[p].push(item);
                    });

                    
                    const parents = Object.keys(grouped).sort((a,b) => getSortOrder(a, 'category_1') - getSortOrder(b, 'category_1'));

                    
                    parents.forEach(p => {
                        const wrapper = document.createElement('div');
                        wrapper.className = 'mb-4';
                        wrapper.innerHTML = `<div class="text-xs font-bold text-teal-700 dark:text-teal-400 mb-2 pl-1 border-l-4 border-teal-500 dark:border-teal-600 leading-none">${formatLabel(p, 'category_1')}</div>`;
                        const listDiv = document.createElement('div');
                        listDiv.className = 'space-y-3 pl-2';

                        
                        grouped[p].sort((a,b) => getSortOrder(a.name, 'category_2', p) - getSortOrder(b.name, 'category_2', p));

                        
                        listDiv.innerHTML = grouped[p].map(item => {
                            const total = item.total || 1; const cp = Math.round((item.correct / total) _ 100); const ip = Math.round((item.incorrect / total) _ 100);
                            return `<div class="space-y-1"><div class="flex justify-between text-xs text-slate-600 dark:text-slate-300"><span class="font-bold truncate w-2/3">${formatLabel(item.name, 'category_2', p)}</span><span>${item.rate}%</span></div><div class="h-2.5 w-full bg-gray-100 dark:bg-slate-700 rounded-full overflow-hidden flex"><div class="h-full bg-teal-500" style="width: ${cp}%"></div><div class="h-full bg-red-500" style="width: ${ip}%"></div></div><div class="text-[10px] text-right text-gray-400">正解:${item.correct} / 不正解:${item.incorrect} / 未:${item.unanswered}</div></div>`;
                        }).join('');

                        
                        wrapper.appendChild(listDiv);
                        cat2Container.appendChild(wrapper);
                    });
                }
            }
        }).getUserStats(quizState.userId, filters); 
    }

    function renderActivityCalendar(activityData) {
        const container = document.getElementById('stats-calendar-container'); container.innerHTML = '';
        const referenceDate = new Date();
        const dataMap = new Map();
        activityData.forEach(a => { dataMap.set(a.date, a.count); });

        const monthFragments = [];
        for (let i = 0; i < 2; i++) {
            const date = new Date(referenceDate.getFullYear(), referenceDate.getMonth() - i, 1);
            const monthName = `${date.getMonth() + 1}月`;
            const daysInMonth = new Date(date.getFullYear(), date.getMonth() + 1, 0).getDate();
            const monthDiv = document.createElement('div');
            monthDiv.innerHTML = `<h4 class="text-xs font-bold mb-2 text-gray-500">${monthName}</h4>`;
            const grid = document.createElement('div'); grid.className = 'calendar-grid';

            
            for(let d=1; d<=daysInMonth; d++) {
                const cell = document.createElement('div'); 
                // CSS priority issue solved by using !important in style block
                cell.className = 'calendar-day text-gray-300 dark:text-gray-600 transition-all rounded-md';
                cell.textContent = d;

                
                const y = date.getFullYear(); 
                const m = String(date.getMonth() + 1).padStart(2, '0'); 
                const dayStr = String(d).padStart(2, '0');
                const key = `${y}-${m}-${dayStr}`;

                
                const count = dataMap.get(key) || 0;

                
                if (count > 0) {
                    cell.classList.add('font-bold');
                    if (count <= 2) cell.classList.add('heat-l1'); 
                    else if (count <= 5) cell.classList.add('heat-l2'); 
                    else if (count <= 10) cell.classList.add('heat-l3'); 
                    else if (count <= 20) cell.classList.add('heat-l4'); 
                    else cell.classList.add('heat-l5');
                } else {
                    cell.classList.add('bg-gray-50', 'dark:bg-slate-700/50');
                }
                grid.appendChild(cell);
            }
            monthDiv.appendChild(grid);
            monthFragments.push(monthDiv);
        }
        monthFragments.reverse().forEach(el => container.appendChild(el));
    }
  </script>

</body>
</html>
