import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:muzic/features/helper_widgets/home_drawer.dart';
import 'package:muzic/features/resources/repositories/player_cubit.dart';
import 'package:muzic/features/resources/repositories/player_state.dart';
import 'package:muzic/features/resources/repositories/songs_list_cubit.dart';
import 'package:muzic/features/resources/repositories/songs_list_repo.dart';
import 'package:muzic/view/home/view/home_screen.dart';
import 'package:muzic/view/mini_player/mini_player.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final List<Widget> _screens = [
    BlocProvider(
      create: (_) => SongsListCubit(repository: SongsListRepository()),
      child: const HomeScreen(),
    ),
    const Center(child: Text("Search Screen")),
    const Center(child: Text("Your Library")),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: const HomeDrawer(),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(icon: const Icon(Icons.menu), onPressed: () => _scaffoldKey.currentState?.openDrawer()),
      ),

      body: Column(
        children: [
          Expanded(
            child: IndexedStack(index: _currentIndex, children: _screens),
          ),
          BlocBuilder<PlayerCubit, PlayerState>(
            builder: (context, state) {
              if (state.currentSong == null) return const SizedBox.shrink();
              return MiniPlayer(song: state.currentSong!, isPlaying: state.isPlaying, onTogglePlay: () => context.read<PlayerCubit>().togglePlay());
            },
          ),
        ],
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: "Search"),
          BottomNavigationBarItem(icon: Icon(Icons.my_library_music), label: "Your Library"),
        ],
      ),
    );
  }
}
