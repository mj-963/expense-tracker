import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:expense_tracker/models/transaction.dart'; // Your TransactionModel
import 'package:expense_tracker/utils/app_colors.dart';
import 'package:expense_tracker/utils/weekly_group.dart';
import 'package:expense_tracker/widgets/app_drawer.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:simple_month_year_picker/simple_month_year_picker.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // For the month-year picker. We filter transactions for the picked month.
  DateTime _selectedMonth = DateTime.now();

  // "Daily" or "Weekly"
  String _groupBy = 'Daily'; // default is daily

  // Bottom navigation index
  int _currentIndex = 0;

  // Firestore stream (filtered by picked month)
  Stream<QuerySnapshot>? _transactionsStream;
  final user = FirebaseAuth.instance.currentUser;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _setupTransactionsStream();
  }

  /// Setup the Firestore query to only get transactions for the selected month.
  void _setupTransactionsStream() {
    if (user == null) return;
    final start = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final end = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);

    _transactionsStream =
        FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .collection('transactions')
            .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
            .where('date', isLessThan: Timestamp.fromDate(end))
            .orderBy('date', descending: true)
            .snapshots();
  }

  /// Month-Year picker
  Future<void> _pickMonthYear() async {
    final newDate = await SimpleMonthYearPicker.showMonthYearPickerDialog(
      context: context,
      selectionColor: AppColors.secondary,
      disableFuture: false,
    );
    setState(() {
      _selectedMonth = newDate;
    });
    _setupTransactionsStream();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: null,
      drawer: AppDrawer(),
      floatingActionButton: FloatingActionButton(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
        onPressed: () {
          // Navigate to new transaction screen
          Navigator.pushNamed(context, '/new-transaction');
        },
        backgroundColor: Colors.amber,
        child: const Icon(Icons.add, color: Colors.black),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _buildBottomNavBar(),
      body:
          _currentIndex == 0
              ? _buildTransactionsView()
              : _buildPlaceholderView(), // For the other tabs
    );
  }

  /// The main Transactions view (SliverAppBar + grouped list)
  Widget _buildTransactionsView() {
    return StreamBuilder<QuerySnapshot>(
      stream: _transactionsStream,
      builder: (context, snapshot) {
        double expenseTotal = 0.0;
        double incomeTotal = 0.0;
        List<TransactionModel> transactions = [];

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return CustomScrollView(
            slivers: [
              _buildSliverAppBar(
                totalBalance: 0.0,
                totalExpense: 0.0,
                totalIncome: 0.0,
              ),
              SliverToBoxAdapter(child: _buildNoTransactionsPlaceholder()),
            ],
          );
        }

        // Parse each doc and sum up totals.
        for (var doc in snapshot.data!.docs) {
          final tx = TransactionModel.fromFirestore(doc);
          transactions.add(tx);
          if (tx.type == 'expense') {
            expenseTotal += tx.amount;
          } else if (tx.type == 'income') {
            incomeTotal += tx.amount;
          }
        }
        final totalBalance = incomeTotal - expenseTotal;

        return CustomScrollView(
          slivers: [
            _buildSliverAppBar(
              totalBalance: totalBalance,
              totalExpense: expenseTotal,
              totalIncome: incomeTotal,
            ),

            // Transactions header row with the "Daily/Weekly" dropdown
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Transactions',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    DropdownButton<String>(
                      value: _groupBy,
                      items: const [
                        DropdownMenuItem(value: 'Daily', child: Text('Daily')),
                        DropdownMenuItem(
                          value: 'Weekly',
                          child: Text('Weekly'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _groupBy = val;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Build daily or weekly grouping
            if (_groupBy == 'Daily')
              _buildDailyGroupedList(_groupByDay(transactions))
            else
              _buildWeeklyGroupedList(_groupByWeek(transactions)),
          ],
        );
      },
    );
  }

  // --------------------------
  //  DAILY GROUPING
  // --------------------------

  /// Group by day. Returns a Map of "yyyy-MM-dd" -> List<TransactionModel>
  Map<String, List<TransactionModel>> _groupByDay(List<TransactionModel> txs) {
    final Map<String, List<TransactionModel>> grouped = {};
    for (var tx in txs) {
      final key = DateFormat('yyyy-MM-dd').format(tx.date);
      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(tx);
    }
    return grouped;
  }

  /// Builds a SliverList for daily grouping: each day has a gray header with the date,
  /// then the transactions for that day.
  Widget _buildDailyGroupedList(Map<String, List<TransactionModel>> grouped) {
    final sortedKeys =
        grouped.keys.toList()
          ..sort((a, b) => b.compareTo(a)); // descending by date string
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final key = sortedKeys[index];
        final dayTxs = grouped[key]!;
        final dateObj = DateTime.parse(key);

        // compute the daily net
        double dayExpense = 0.0;
        double dayIncome = 0.0;
        for (var tx in dayTxs) {
          if (tx.type == 'expense') dayExpense += tx.amount;
          if (tx.type == 'income') dayIncome += tx.amount;
        }
        final dayNet = dayIncome - dayExpense;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Day header row
            Container(
              width: double.infinity,
              color: Colors.grey[200],
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat('EEE, dd/MM/yyyy').format(dateObj),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    '${dayNet >= 0 ? '+' : ''}₦${dayNet.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 14,
                      color: dayNet >= 0 ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
            ),
            // Transactions for this day
            Column(
              children: dayTxs.map((tx) => _buildTransactionTile(tx)).toList(),
            ),
          ],
        );
      }, childCount: sortedKeys.length),
    );
  }

  // --------------------------
  //  WEEKLY GROUPING
  // --------------------------

  /// Groups transactions by their "week start" (e.g. Monday).
  /// Returns a list of WeeklyGroup sorted in descending order by startDate.
  List<WeeklyGroup> _groupByWeek(List<TransactionModel> txs) {
    // Key: "yyyy-MM-dd" for the Monday of that week
    final Map<String, List<TransactionModel>> map = {};

    for (var tx in txs) {
      // find the Monday of that week (or Sunday if prefered)
      final weekStart = _mondayOf(tx.date);
      final key = DateFormat('yyyy-MM-dd').format(weekStart);

      map.putIfAbsent(key, () => []);
      map[key]!.add(tx);
    }

    // build WeeklyGroup objects
    final List<WeeklyGroup> result = [];
    for (var entry in map.entries) {
      final startKey = entry.key;
      final startDate = DateTime.parse(startKey);
      final endDate = startDate.add(const Duration(days: 6));
      final txList = entry.value;

      double expense = 0.0;
      double income = 0.0;
      for (var tx in txList) {
        if (tx.type == 'expense') expense += tx.amount;
        if (tx.type == 'income') income += tx.amount;
      }
      final net = income - expense;

      result.add(
        WeeklyGroup(
          startDate: startDate,
          endDate: endDate,
          totalExpense: expense,
          totalIncome: income,
          net: net,
          transactions: txList,
        ),
      );
    }

    // Sort descending by startDate
    result.sort((a, b) => b.startDate.compareTo(a.startDate));
    return result;
  }

  /// Return the Monday of the given date's week.
  DateTime _mondayOf(DateTime d) {
    final weekday = d.weekday; // Monday=1 ... Sunday=7
    // Subtract (weekday - 1) days to get back to Monday
    return DateTime(
      d.year,
      d.month,
      d.day,
    ).subtract(Duration(days: weekday - 1));
  }

  /// Builds a SliverList for weekly grouping. Each group is an ExpansionTile
  /// showing the date range (e.g. "16/02 - 22/02") + net, and inside we show
  /// a daily breakdown for that week.
  Widget _buildWeeklyGroupedList(List<WeeklyGroup> weeklyGroups) {
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final group = weeklyGroups[index];
        return _buildWeeklyExpansionTile(group);
      }, childCount: weeklyGroups.length),
    );
  }

  /// Renders one weekly group as an ExpansionTile.
  /// The title shows "startDate - endDate" and net.
  /// The children show a daily breakdown inside that week.
  Widget _buildWeeklyExpansionTile(WeeklyGroup group) {
    final startLabel = DateFormat('dd/MM').format(group.startDate);
    final endLabel = DateFormat('dd/MM').format(group.endDate);
    final netLabel =
        '${group.net >= 0 ? '+' : ''}₦${group.net.toStringAsFixed(2)}';

    // For the subtitle, we can show expense & income or just skip it.
    final expenseLabel = 'Expense: ₦${group.totalExpense.toStringAsFixed(2)}';
    final incomeLabel = 'Income: ₦${group.totalIncome.toStringAsFixed(2)}';

    // Build a daily breakdown inside this week.
    final dailyMap = _groupByDay(group.transactions);
    final dailyKeys =
        dailyMap.keys.toList()..sort((a, b) => b.compareTo(a)); // descending

    return ExpansionTile(
      // The main row
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$startLabel - $endLabel'),
          Text(
            netLabel,
            style: TextStyle(
              color: group.net >= 0 ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      // Subtitle can show expense & income
      subtitle: Row(
        children: [
          Text(expenseLabel, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 8),
          Text(incomeLabel, style: const TextStyle(fontSize: 12)),
        ],
      ),
      children: [
        // For each day in this week, show a mini daily header + transactions
        for (var dayKey in dailyKeys) ...[
          _buildWeeklyDayHeader(dayKey, dailyMap[dayKey]!),
        ],
      ],
    );
  }

  /// Within a weekly group, build a row for each day + its transactions.
  Widget _buildWeeklyDayHeader(String dayKey, List<TransactionModel> txs) {
    final dateObj = DateTime.parse(dayKey);
    // Compute the day's net
    double dayExpense = 0.0;
    double dayIncome = 0.0;
    for (var tx in txs) {
      if (tx.type == 'expense') dayExpense += tx.amount;
      if (tx.type == 'income') dayIncome += tx.amount;
    }
    final dayNet = dayIncome - dayExpense;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Gray header row for the day
        Container(
          width: double.infinity,
          color: Colors.grey[200],
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('EEE, dd/MM/yyyy').format(dateObj),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                '${dayNet >= 0 ? '+' : ''}₦${dayNet.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 14,
                  color: dayNet >= 0 ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
        ),
        // Then each transaction for that day
        for (var tx in txs) _buildTransactionTile(tx),
      ],
    );
  }

  // --------------------------
  //  SLIVER APP BAR
  // --------------------------

  /// SliverAppBar pinned, with totalBalance, totalExpense, totalIncome
  SliverAppBar _buildSliverAppBar({
    required double totalBalance,
    required double totalExpense,
    required double totalIncome,
  }) {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 230,
      backgroundColor: AppColors.primary,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        background: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Row: "My Wallet" and "Month-Year" (pickable)
                Row(
                  children: [
                    //menu icon
                    IconButton(
                      onPressed: () {
                        _scaffoldKey.currentState?.openDrawer();
                      },
                      icon: Icon(Icons.menu, size: 30),
                    ),
                    SizedBox(width: 10),
                    Text(
                      'My Wallet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[900],
                      ),
                    ),
                    Spacer(),
                    InkWell(
                      onTap: _pickMonthYear,
                      child: Row(
                        children: [
                          Icon(Icons.arrow_back_ios_outlined, size: 16),
                          Text(
                            _formatMonthYear(_selectedMonth),
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[900],
                            ),
                          ),
                          Icon(Icons.arrow_forward_ios_outlined, size: 16),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Centered "Total Balance"
                const Text(
                  'Total Balance',
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                ),
                const SizedBox(height: 4),
                Text(
                  '₦${totalBalance.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[900],
                  ),
                ),
                const SizedBox(height: 16),
                // Row: Expense & Income boxes
                Row(
                  children: [
                    // Expense
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.red.withAlpha(20),
                                borderRadius: BorderRadius.all(
                                  Radius.circular(12),
                                ),
                              ),
                              child: Icon(
                                Icons.arrow_upward_rounded,
                                color: Colors.red,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Column(
                              children: [
                                const Text(
                                  'Expense',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '₦${totalExpense.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Income
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.green.withAlpha(20),
                                borderRadius: BorderRadius.all(
                                  Radius.circular(12),
                                ),
                              ),
                              child: Icon(
                                Icons.arrow_downward_rounded,
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Column(
                              children: [
                                const Text(
                                  'Income',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '₦${totalIncome.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --------------------------
  //  BOTTOM NAV BAR
  // --------------------------

  Widget _buildBottomNavBar() {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8.0,
      child: SizedBox(
        height: 70,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(0, Icons.list, 'Transaction'),
            _buildNavItem(1, Icons.bar_chart, 'Report'),
            const SizedBox(width: 40),
            _buildNavItem(2, Icons.account_balance_wallet, 'Budget'),
            _buildNavItem(3, Icons.person, 'Mine'),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? AppColors.secondary : Colors.grey[600];
    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      child: SizedBox(
        width: 70,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              overflow: TextOverflow.fade,
              style: TextStyle(fontSize: 12, color: color),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------
  //  PLACEHOLDER TABS
  // --------------------------

  Widget _buildPlaceholderView() {
    String title;
    switch (_currentIndex) {
      case 1:
        title = 'Report';
        break;
      case 2:
        title = 'Budget';
        break;
      case 3:
        title = 'Mine';
        break;
      default:
        title = '';
    }
    return Center(
      child: Text(
        '$title Page',
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      ),
    );
  }

  // --------------------------
  //  MISC HELPERS
  // --------------------------

  Widget _buildNoTransactionsPlaceholder() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 50),
          Icon(Icons.insert_drive_file, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text(
            "No transaction in selected time period",
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionTile(TransactionModel tx) {
    return GestureDetector(
      onLongPressStart: (details) async {
        // Show a popup menu at the long press location.
        await showMenu(
          context: context,
          position: RelativeRect.fromLTRB(
            details.globalPosition.dx,
            details.globalPosition.dy,
            details.globalPosition.dx,
            details.globalPosition.dy,
          ),
          items: [
            PopupMenuItem(
              value: 'edit',
              child: Text('Edit'),
              onTap: () {
                // Navigate to edit screen
                Navigator.pushNamed(
                  context,
                  '/new-transaction',
                  arguments: {'transaction': tx},
                );
              },
            ),
            PopupMenuItem(
              value: 'delete',
              child: Text('Delete'),
              onTap: () async {
                await deleteTransaction(tx.id);
              },
            ),
          ],
        );
      },
      child: ListTile(
        leading: Icon(
          tx.type == 'expense'
              ? Icons.arrow_downward
              : tx.type == 'income'
              ? Icons.arrow_upward
              : Icons.swap_horiz,
          color:
              tx.type == 'expense'
                  ? Colors.red
                  : tx.type == 'income'
                  ? Colors.green
                  : Colors.blueGrey,
        ),
        title: Text(
          '${tx.type[0].toUpperCase()}${tx.type.substring(1)}: ₦${tx.amount.toStringAsFixed(2)}',
        ),
        subtitle: Text('${_formatDate(tx.date)} - ${tx.category}'),
        isThreeLine: true,
        trailing: Text(
          tx.type == 'expense'
              ? '-₦${tx.amount.toStringAsFixed(2)}'
              : tx.type == 'income'
              ? '+₦${tx.amount.toStringAsFixed(2)}'
              : 'Transfer',
          style: TextStyle(
            color:
                tx.type == 'expense'
                    ? Colors.red
                    : tx.type == 'income'
                    ? Colors.green
                    : Colors.blueGrey,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('EEE, dd/MM/yyyy').format(date);
  }

  String _formatMonthYear(DateTime date) {
    // e.g. "2025 Feb"
    return '${date.year} ${DateFormat.MMM().format(date)}';
  }

  Future<void> deleteTransaction(String transactionId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // No user logged in;
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('transactions')
          .doc(transactionId)
          .delete();
    } catch (e) {
      rethrow;
    }
  }
}
