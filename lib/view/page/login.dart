import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luogo/cubit/login/login_cubit.dart';
import 'package:luogo/cubit/login/login_state.dart';

// _ColorOption(
//   color: Colors.red,
//   isSelected: cubit.selectedColor == Colors.red,
//   onTap: () => cubit.selectColor(Colors.red),
// ),
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => LoginCubit(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Login')),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              BlocBuilder<LoginCubit, LoginState>(
                builder: (context, state) {
                  final cubit = context.read<LoginCubit>();
                  return Column(
                    children: [
                      Stack(
                        children: [
                          Container(
                            width: 200, // Diameter of the circle
                            height: 200,
                            decoration: BoxDecoration(
                              color: cubit.selectedColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          if (cubit.nameController.text.isNotEmpty)
                            Positioned.fill(
                              child: Center(
                                child: Text(
                                  cubit.nameController.text[0],
                                  style: TextStyle(
                                    // Optional: Adjust font size/weight for visibility
                                    fontSize: 100,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      SizedBox(
                        height: 20,
                      ),
                      Column(
                        children: [
                          if (cubit.nameController.text.isNotEmpty) ...[
                            Text(
                              cubit.nameController.text,
                              style: TextStyle(fontSize: 20),
                            ),
                            const SizedBox(height: 20),
                          ],
                          // Other widgets...
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: cubit.nameController,
                              decoration: const InputDecoration(
                                labelText: 'Enter your name',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(
                                Icons.colorize), // Eye dropper style icon
                            onPressed: () {},
                            tooltip: 'Pick a color',
                          ),
                        ],
                      )
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
