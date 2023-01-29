import setuptools

setuptools.setup(
    name='opn_tools',
    version='0.0.1',
    packages=[
        'mkopn',
    ],
    include_package_data=True,
    entry_points={
        'console_scripts': [
            'mkopn = mkopn:main',
        ],
    },
)
