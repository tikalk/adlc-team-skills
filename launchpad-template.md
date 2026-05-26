# Launchpad - תבנית ללקוח חדש

> **מטרה**: זו תבנית מאסטר ש-AI Lead משכפל לכל לקוח חדש. כוללת רשימת משימות, תבניות פגישות סנכרון, ולקחים שנלמדו.
> 
> **הנחיה**: העתק את הטאב הזה כטאב חדש בשם הלקוח (לדוג': AppWorks) ומלא את הפרטים

---

## מידע כללי

| שדה | תוכן |
|-----|------|
| **שם לקוח** | |
| **AI Lead מטעם טיקל** | |
| **צוות טיקל נוסף** | |
| **איש קשר בלקוח** | |
| **מוביל טכנולוגי בלקוח** | |
| **תאריך Kickoff** | |
| **תאריך Handover צפוי** | (6 שבועות מ-Kickoff) |

---

## ציר זמן - 6 שבועות מ-Kickoff

```
שבוע 1          | שבועות 2-3       | שבועות 4-5          | שבוע 6
Phase 1:        | Phase 2:         | Phase 3:            | Phase 4:
Scan, Baseline  | Workshop         | Embedded            | Handover
& Adaptation    | (4 מפגשים)       | Execution (Sprint)  | & ROI
```

---

## משימות שבועיות (Task Tracker)

| Assignee | משימה | תאריך יעד | סטטוס |
|----------|-------|-----------|-------|

### Phase 1 - Scan & Baseline (שבוע 1)

| | פתיחת ערוץ Slack משותף (External) לתקשורת שוטפת | | ☐ |
| | שליחת סיכום פגישה מסודר לכל פגישה | | ☐ |
| | יצירת מסמך משותף להתקדמות התהליך (Google Doc עם תמלולים) | | ☐ |
| | בחירת KPI של הארגון או שימוש בסקר baseline שלנו | | ☐ |
| | יצירת שאלון/סקר (Google Form) למיפוי הרגלי השימוש הנוכחיים ב-AI | | ☐ |
| | הקמת ה-Repo הראשוני של team-ai-directives (מבוסס Open Source של טיקל) | | ☐ |
| | הרצת `level up init` / סריקה על הקוד של הלקוח לזיהוי חוקים ופרסונות | | ☐ |
| | מיפוי פרסונות/קבוצות הנדסה ובחירת משימות לפי הפרסונות | | ☐ |
| | מתן גישה לקוד (GitHub/GitLab read-only) | | ☐ |
| | שליחת יוזרים של טיקל ב-GitHub ללקוח | | ☐ |
| | הכנת הקונטקסט הראשוני ובניית ה-Directives | | ☐ |
| | ה-Scenario לתרגילי קבוצה 1 | | ☐ |
| | ה-Scenario לתרגילי קבוצה 2 | | ☐ |
| | ה-Scenario לתרגילי קבוצה 3 | | ☐ |

### Phase 2 - Workshop (שבועות 2-3)

| | סידור הגישה ל-Google Classroom ב-Admin | | ☐ |
| | ארגון ה-Google Classroom והזמנת המשתתפים | | ☐ |
| | לינק ל-Zoom להקלטה כולל breakout rooms על המשתמש של training-zoom | | ☐ |
| | לארגן שקפים של התרגילים במצגת הראשית | | ☐ |
| | הכנת סביבת עבודה (שלב ב') - חיבור טכני (MCP) | | ☐ |
| | ביצוע ה-Scenario לתרגילי קבוצה 1 | | ☐ |
| | ביצוע ה-Scenario לתרגילי קבוצה 2 | | ☐ |
| | ביצוע ה-Scenario לתרגילי קבוצה 3 | | ☐ |
| | העברה של מודל הדרכה 3 - level-up | | ☐ |
| | העברה של מודל הדרכה 4 - spec-kit | | ☐ |

### Phase 3 - Embedded Execution (שבועות 4-5)

| | להגדיר את הלו"ז ל-sprint או timebox | | ☐ |
| | לפתוח Repositories נפרדים עבור ה-Directives (לפי צוותים/סטאקים) | | ☐ |
| | להכין ולשלוח Cheat Sheet (דף עזר/פקודות) למפתחים | | ☐ |
| | ללמד את ה-AI-Lead של הלקוח את ה-levelup | | ☐ |
| | להחליט על השימוש ב-adlc-spec-kit | | ☐ |
| | קביעת פגישות Huddle קבועות (2x בשבוע, 30 דקות) | | ☐ |

### Phase 4 - Handover & ROI (שבוע 6)

| | שליחת סקר ה-Baseline המעודכן למפתחים | | ☐ |
| | סיכום התהליך כולל השוואה בין סקרי ה-baseline | | ☐ |
| | הזמנת מפתחים חדשים ל-Google Classroom (במידת הצורך) | | ☐ |
| | תיאום והגדרת מסגרת עבודה (Scoping) להמשך ליווי | | ☐ |
| | סגירת/מעבר ערוץ Slack | | ☐ |

---

## תבניות פגישות סנכרון

### 1. Kickoff Meeting (Phase 1)

```
📅 [תאריך] | Kickoff Meeting - [שם לקוח]
👥 משתתפים: [טיקל: ...] [לקוח: ...]

--- אג'נדה ---
1. יישור קו (Alignment)
   - הצגת המתודולוגיה (Agentic SDLC / 12 Factors)
   - מיפוי Tech Stack & AI Maturity לכל צוות/פרסונה
   - הגדרת מדדי הצלחה (Success Metrics / KPIs)

2. תכנון לוגיסטי
   - תאריכי סדנאות (4 מפגשים x 3 שעות)
   - פורמט: פיזי / אונליין / היברידי
   - שפת העברה: עברית / אנגלית

3. גישות וכלים
   - גישה ל-GitHub/GitLab (Read Only)
   - רישיונות AI קיימים (Claude/Copilot/ChatGPT)
   - בדיקת IDE (Cursor/VS Code/IntelliJ)

--- החלטות ---
- [...]

--- משימות לביצוע (Action Items) ---
באחריות טיקל:
- [ ] ...
באחריות הלקוח:
- [ ] ...

--- תאריך פגישה הבאה ---
[...]
```

---

### 2. Workshop Prep Meeting (Phase 1→2)

```
📅 [תאריך] | Workshop Prep - [שם לקוח]
👥 משתתפים: [צוות טיקל בלבד]

--- אג'נדה ---
1. סטטוס משימות Phase 1
   - [ ] Access לקוד - התקבל?
   - [ ] Baseline Survey - הופץ/מולא?
   - [ ] Directives repo - הוקם?
   - [ ] Scenarios - הוכנו?

2. חלוקת תפקידים לסדנה
   - Lead (מעביר ראשי): [...]
   - Support/Shadow (תמיכה טכנית, breakout rooms): [...]

3. סקירת תרחישי תרגול
   - קבוצה 1: [תיאור + repo]
   - קבוצה 2: [תיאור + repo]
   - קבוצה 3: [תיאור + repo]

4. לוגיסטיקה
   - [ ] Zoom links + Breakout rooms
   - [ ] Google Classroom מוכן
   - [ ] מצגת מעודכנת

--- משימות ---
- [ ] ...
```

---

### 3. Phase 3 Setup Meeting (Phase 2→3)

```
📅 [תאריך] | Phase 3 Setup - [שם לקוח]
👥 משתתפים: [טיקל + מובילים טכנולוגיים של הלקוח]

--- אג'נדה ---
1. Recap של הסדנאות
   - מה עבד טוב?
   - אילו נקודות דורשות חיזוק?

2. הגדרת Sprint/Timebox
   - תכולת הספרינט
   - המלצה: הקטנת Capacity ב-15-20%
   - החרגות מהתהליך (צוותים/אנשים שלא משתתפים)

3. ארכיטקטורת Directives
   - repo אחד או מפוצל לפי צוותים?
   - מנגנון עדכון: Tags + ZIP vs. Submodules
   - מי ה-Curator של כל repo?

4. לו"ז פגישות Huddle
   - ימים ושעות קבועים (מומלץ: שני + רביעי, 17:30)
   - משך: 30 דקות

5. הכנת Cheat Sheet למפתחים
   - תהליך Setup
   - Quick mode vs. Spec mode
   - פקודות נפוצות

--- החלטות ---
- [...]

--- משימות ---
באחריות טיקל:
- [ ] שליחת זימונים ל-Huddles
- [ ] הכנת ושליחת Cheat Sheet
- [ ] Push הגדרות ראשוניות ל-Directives repos
באחריות הלקוח:
- [ ] פתיחת repos נפרדים (אם הוחלט)
- [ ] הגדרת תכולת ספרינט
- [ ] הענקת הרשאות כתיבה ל-Directives repos
```

---

### 4. Huddle (Phase 3 - חוזרת פעמיים בשבוע)

```
📅 [תאריך] | Huddle #[X] - [שם לקוח]
👥 משתתפים: [...]

--- סטטוס לפי צוות ---
צוות [א']:
- [ ] התחילו לעבוד עם הכלים?
- [ ] באגים/חסמים שנתקלו בהם?
- [ ] עדכוני Directives נדרשים?

צוות [ב']:
- [ ] ...

--- נושאים טכניים שעלו ---
1. [תיאור בעיה + פתרון מוצע]
2. [...]

--- Directives Updates ---
- [ ] Rules חדשים שצריך להוסיף
- [ ] Skills שזוהו מעבודת המפתחים
- [ ] Constitution דורש עדכון?

--- משימות ---
- [ ] ...

--- פגישה הבאה ---
[תאריך + שעה]
```

---

### 5. Handover Meeting (Phase 4)

```
📅 [תאריך] | Handover - [שם לקוח]
👥 משתתפים: [טיקל + הנהלה + מובילים טכניים]

--- אג'נדה ---
1. מדידת הצלחה
   - השוואת סקרי Baseline (לפני vs. אחרי)
   - Toil Reduction (שעות שנחסכו)
   - AI Trust & Confidence Delta
   - Maturity Progression (רמה 1-2 → רמה 5-6)

2. סיכום תוצרים
   - team-ai-directives repo(s) - מצב נוכחי
   - Google Classroom - חומרים זמינים
   - כללים/Skills שנוצרו

3. תמיכה והמשך
   - ערוץ Slack - נשאר פתוח ל-[X] שבועות
   - מבנה תמיכה (Subscription)
   - מי ה-AI Lead הפנימי?

4. הרחבה עתידית (אופציונלי)
   - Product Engineering flow
   - צוותים/מחלקות נוספים
   - כלים נוספים

--- החלטות ---
- [...]

--- משימות סיום ---
- [ ] שליחת סקר baseline מעודכן
- [ ] הכנת דו"ח ROI
- [ ] העברת בעלות repos
- [ ] סגירת ערוץ Slack (בתום תקופת תמיכה)
```

---

## לקחים והנחיות מניסיון

### מהלקחים של Precise ו-IVIX:

1. **התנגדות - לטפל בענווה** (הלקח של שירה ב-Precise): מפתחים בכירים עשויים להתנגד בתחילה. לא לכפות - להוכיח ערך בהדגמה.

2. **עומס קוגניטיבי** (הלקח של CytoReason): לא להציף הכל בבת אחת. ללמד spec-driven קודם כקונספט, ורק אח"כ להוסיף CLI ו-Git workflows.

3. **Constitution מינימליסטי**: ה-Constitution חייב להישאר קצר ומדויק. כללים פרטניים ב-Rules, לא ב-Constitution.

4. **שמות ברנצ'ים**: להוסיף כלל מפורש לפורמט שמות ברנצ'ים ב-Constitution/Rules למניעת אי-דטרמיניסטיות.

5. **קומיטים אוטומטיים**: לוודא שהגדרות Git/Extension מונעות קומיטים אוטומטיים.

6. **פרסונות ותרחישים**: להתאים תרגילים לקוד האמיתי של הלקוח, לא תרחישים גנריים.

7. **שגרירים (Allies)**: לזהות מפתחים חזקים מוקדם והפוך אותם לשגרירים פנימיים.

8. **Submodules vs. Tags**: העדיפו Tags + ZIP על פני Submodules - פשוט יותר למפתחים.

9. **Google Classroom**: להקפיד שמשתתפים נכנסים דרך Classroom ולא דרך לינקים ישירים.

10. **Capacity בספרינט**: להמליץ ללקוח להקטין capacity ב-15-20% בספרינט הראשון.

---

## תהליך יצירת תרחישים - Prompt Recipe

### שלב א': סריקת הקוד (`levelup init`)

**פעולה**: הרץ `levelup init` על ה-workspace של הלקוח

```bash
levelup init
```

**הפניה**: התבסס על מסמך הסדנה (`@[client]-workshop.md`)

**פלט**: קובץ `cdr.md` עם תבניות שזוהו מהקוד

---

### שלב ב': יצירת Mission Brief

השתמש בפרומפט הבא:

```
I need to create a new Mission Brief for the objective: 
"[ONE PARAGRAPH SCENARIO DESCRIPTION - תיאור התרחיש בפסקה אחת]"


1. Propose a one-sentence Goal.
2. Measurable Success Criteria.
3. Define the key Constraints (e.g., must utilize existing reporting building blocks, ensure secure scheduling execution). 
4. Using web search, research best practices for this task. 
5. Help me choose the best components from our team's library for the Context Packet using @[client]-team-ai-directives/ (suggest an [Angular/Django/React/.NET/etc] persona, relevant style guides and a high-quality example).
6. Output the final result in a file named `mission-brief.md` 
```

**דוגמה מתוך Precise**:
```
"Implement a Report Templates and Scheduling mechanism in the Law-yal Billing system. 
Create a Django model to save report configurations (columns, filters, grouping) and 
scheduling rules, and build an Angular UI for users to create, save, and schedule these templates."
```

---

### שלב ג': יצירת תכנית ביצוע (Plan)

השתמש בפרומפט הבא:

```
Generate a detailed step-by-step execution plan based on the `mission-brief.md`.


1. Break down the tasks across the [BACKEND] (e.g., Django models, scheduling logic) and [FRONTEND] (e.g., Angular dynamic template builder UI).
2. For each step, tag it as either [SYNC] (Interactive design of the dynamic template schema) or [ASYNC] (Delegated to Agent for boilerplate CRUD/Scheduling setup) and briefly explain why.
3. Format the output as a Markdown Checklist (using `- [ ]`) inside a code block.
4. Output the final result in a file named `plan.md` 
```

---

### שלב ד': בדיקות מבוססות סיכון (Risk-Based Tests)

השתמש בפרומפט הבא:

```
Generate risk-based tests for `plan.md`.


The main risk: "[RISK DESCRIPTION - תיאור הסיכון העיקרי, לדוג': The scheduling mechanism might fail or send reports to the wrong users, and the dynamic JSON configuration for the templates might break the Angular UI if parsed incorrectly.]"


Focus on:
1. Writing a [BACKEND FRAMEWORK] unit test to ensure [RISK AREA 1].
2. Writing a [FRONTEND FRAMEWORK] test to verify [RISK AREA 2].
3. Output the final result in a file named `risk-based-tests.md` 
```

---

### שלב ה': תיעוד (Trace Summary)

בסיום העבודה על התרחיש, השתמש בפרומפט הבא:

```
The work for the "[FEATURE NAME]" feature is complete. Draft a Trace Summary including: 
1. Problem: A brief summary of the initial goal. 
2. Key Decisions: Outline choices made (e.g., how the dynamic JSON schema is stored in Django, state management in Angular for the builder, scheduling execution method). 
3. Final Solution: Briefly describe the final outcome.
4. Output the final result in a file named `trace-log.md` 
```

---

### שלב ו': שכפול לפרסונות (Multi-Persona)

ליצירת תרחישים לכל פרסונה בהתבסס על מסמך תבנית:

```
based on the scenarios tab in google doc id [SCENARIOS_DOC_ID] 
per persona create for me a new google doc with each persona in a tab 
using the precise document [TEMPLATE_DOC_ID] as a template, 
keep formats and styling
```

**הערות**:
- `[SCENARIOS_DOC_ID]` = מזהה מסמך ה-Google Doc עם הטאב "scenarios"
- `[TEMPLATE_DOC_ID]` = מזהה מסמך תבנית (לדוג': המסמך של Precise)

---

## ציר זמן לדוגמה - Precise

| תאריך | אירוע |
|-------|-------|
| Feb 16 | פגישת מכירות ראשונית |
| Mar 2 | Kickoff |
| Mar 8-16 | סדנאות (4 מפגשים) |
| Mar-Apr | הפסקה בשל המצב הביטחוני |
| Apr 23 - May 13 | Phase 3 Huddles (פעמיים בשבוע) |
| May 24 | Handover סופי |

> **הערה**: Precise נמשכה יותר מ-6 שבועות בגלל הפסקה ביטחונית. הטמפרטורה הרגילה היא 6 שבועות רצופים.

---

## מסמכי עזר מומלצים

- [The Twelve-Factor Agentic SDLC - Guide Tab](https://docs.google.com/document/d/1qH8wjVQr5anMRcGY74IvTQiLeS5E6CgcH28q_IH5ic4)
- [Precise Tab - דוגמה מלאה](https://docs.google.com/document/d/1qH8wjVQr5anMRcGY74IvTQiLeS5E6CgcH28q_IH5ic4)
- [IVIX Tab - דוגמה בתהליך](https://docs.google.com/document/d/1qH8wjVQr5anMRcGY74IvTQiLeS5E6CgcH28q_IH5ic4)

---

**נוצר**: [תאריך]  
**על ידי**: [שם AI Lead]  
**מבוסס על**: Launchpad Template v1.0
